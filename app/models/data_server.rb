require 'csv'
class DataServer

  def initialize(org_account)
    @org_account = org_account
    @org = org_account.organization
  end

  def requires_username_and_password?() true; end

  def import_all(date_from)
    Rails.logger.debug 'Importing Profiles'
    designation_profiles = import_profiles
    designation_profiles.each do |p|
      Rails.logger.debug 'Importing balances'
      import_profile_balance(p)
      Rails.logger.debug 'Importing Donors'
      import_donors(p, date_from)
      Rails.logger.debug 'Importing Donations'
      import_donations(p, date_from)
    end
  end

  def import_profiles
    designation_profiles = []
    if @org.profiles_url.present?
      check_credentials!

      profiles.each do |profile|
        designation_profiles << Retryable.retryable do
          @org.designation_profiles.where(user_id: @org_account.person_id, name: profile[:name], code: profile[:code]).first_or_create
        end
      end
    else
      designation_profiles << Retryable.retryable do
        @org.designation_profiles.where(user_id: @org_account.person_id, name: @org_account.person.to_s).first_or_create
      end
    end
    designation_profiles
  end

  def get_account_list(profile)
    profile.find_or_create_account_list
  end

  def import_donors(profile, date_from = nil)
    check_credentials!
    user = @org_account.user

    account_list = get_account_list(profile)

    begin
      response = get_response(@org.addresses_url,
                              get_params(@org.addresses_params, {profile: profile.code.to_s,
                                                                 datefrom: (date_from || @org.minimum_gift_date).to_s,
                                                                 personid: @org_account.remote_id}))
    rescue Errors::UrlChanged => e
      @org.update_attributes(addresses_url: e.message)
      retry
    end

    CSV.new(response, headers: :first_row).each do |line|
      line['LAST_NAME'] = line['LAST_NAME_ORG']
      line['FIRST_NAME'] = line['ACCT_NAME'] if line['FIRST_NAME'].blank?

      begin
        Person.transaction do
          donor_account = add_or_update_donor_account(line, profile, account_list)

          # handle bad data
          unless %w[P O].include?(line['PERSON_TYPE'])
            Airbrake.notify(
              :error_class   => "Unknown PERSON_TYPE",
              :error_message => "Unknown PERSON_TYPE: #{line['PERSON_TYPE']}",
              :parameters    => {line: line, org: @org.inspect, user: @user.inspect, org_account: @org_account.inspect}
            )
            # Go ahead and assume this is a person
            line['PERSON_TYPE'] = 'P'
          end

          case line['PERSON_TYPE']
          when 'P' # Person
            # Create or update people associated with this account
            primary_person, primary_contact_person = add_or_update_primary_contact(account_list, user, line, donor_account)

            # Now the secondary person (persumably spouse)
            if line['SP_FIRST_NAME'].present?
              spouse, contact_spouse = add_or_update_spouse(account_list, user, line, donor_account)
              # Wed the two peple
              primary_person.add_spouse(spouse)
              primary_contact_person.add_spouse(contact_spouse)
            end
          when 'O' # Company/Organization
            add_or_update_company(account_list, user, line, donor_account)
          end
        end
      rescue ArgumentError => e
        raise line.inspect + "\n\n" + e.message.inspect
      end
    end
    true
  end

  def import_donations(profile, date_from = nil, date_to = nil)
    check_credentials!

    # if no date_from was passed in, use min date from query_ini
    date_from = @org.minimum_gift_date || '1/1/2004' if date_from.blank?
    date_to = Time.now.strftime("%m/%d/%Y") if date_to.blank?

    begin
      response = get_response(@org.donations_url,
                              get_params(@org.donations_params, {profile: profile.code.to_s,
                                                                 datefrom: date_from,
                                                                 dateto: date_to,
                                                                 personid: @org_account.remote_id}))
    rescue Errors::UrlChanged => e
      @org.update_attributes(donations_url: e.message)
      retry
    end


    CSV.new(response, headers: :first_row).each do |line|
      designation_account = find_or_create_designation_account(line['DESIGNATION'], profile)
      add_or_update_donation(line, designation_account, profile)
    end
  end

  def import_profile_balance(profile)
    check_credentials!

    balance = profile_balance(profile.code)
    attributes = {balance: balance[:balance], balance_updated_at: balance[:date]}
    profile.update_attributes(attributes, without_protection: true)

    if balance[:designation_numbers]
      attributes.merge!(:name => balance[:account_names].first) if balance[:designation_numbers].length == 1
      balance[:designation_numbers].each_with_index do |number, i|
        da = find_or_create_designation_account(number, profile, attributes)
      end
    end
  end

  def check_credentials!
    raise OrgAccountMissingCredentialsError, I18n.t('data_server.missing_username_password') unless @org_account.username && @org_account.password
    raise OrgAccountInvalidCredentialsError, I18n.t('data_server.invalid_username_password', org: @org) unless @org_account.valid_credentials?
  end

  def validate_username_and_password
    begin
      if @org.profiles_url.present?
        begin
          get_response(@org.profiles_url, get_params(@org.profiles_params))
        rescue Errors::UrlChanged => e
          @org.update_attributes(profiles_url: e.message)
          retry
        end
      else
        begin
          get_response(@org.account_balance_url, get_params(@org.account_balance_params))
        rescue Errors::UrlChanged => e
          @org.update_attributes(account_balance_url: e.message)
          retry
        end
      end
    rescue DataServerError => e
      if e.message =~ /password/
        return false
      else
        raise e
      end
    end
    true
  end

  def profiles_with_designation_numbers
    unless @profiles_with_designation_numbers
      @profiles_with_designation_numbers = profiles.collect do |profile|
        {designation_numbers: designation_numbers(profile[:code])}
         .merge(profile.slice(:name, :code, :balance, :balance_udated_at))
      end
    end
    @profiles_with_designation_numbers
  end

  protected
  def profile_balance(profile_code)
    balance = {}
    begin
      response = get_response(@org.account_balance_url,
                              get_params(@org.account_balance_params, {profile: profile_code.to_s}))
    rescue Errors::UrlChanged => e
      @org.update_attributes!(account_balance_url: e.message)
      retry
    end

    # This csv should always only have one line (besides the headers)
    begin
      CSV.new(response, headers: :first_row).each do |line|
        balance[:designation_numbers] = line['EMPLID'].split(',').collect {|e| e.gsub('"','')}
        balance[:account_names] = line['ACCT_NAME'].split('\n')
        balance_match = line['BALANCE'].match(/([-]?\d+\.?\d*)/)
        balance[:balance] = balance_match[0] if balance_match
        balance[:date] = line['EFFDT'] ? DateTime.strptime(line['EFFDT'], "%Y-%m-%d %H:%M:%S") : Time.now
        break
      end
    rescue NoMethodError
      raise response.inspect
    end
    balance
  end

  def designation_numbers(profile_code)
    balance = profile_balance(profile_code)
    balance[:designation_numbers]
  end


  def profiles
    unless @profiles
      @profiles = []
      unless @org.profiles_url.blank?
        begin
          response = get_response(@org.profiles_url, get_params(@org.profiles_params))
        rescue Errors::UrlChanged => e
          @org.update_attributes(profiles_url: e.message)
          retry
        end
        CSV.new(response, headers: :first_row).each do |line|
          name = line['PROFILE_DESCRIPTION'] || line['ROLE_DESCRIPTION']
          code = line['PROFILE_CODE'] || line['ROLE_CODE']
          @profiles << {name: name, code: code}
        end
      end
    end
    @profiles
  end

  def get_params(raw_params, options={})
    params_string = raw_params.sub('$ACCOUNT$', @org_account.username)
                              .sub('$PASSWORD$', @org_account.password)
    params_string.sub!('$PROFILE$', options[:profile]) if options[:profile]
    params_string.sub!('$DATEFROM$', options[:datefrom]) if options[:datefrom]
    params_string.sub!('$DATETO$', options[:dateto]) if options[:dateto].present?
    params_string.sub!('$PERSONIDS$', options[:personid].to_s) if options[:personid].present?
    params = Hash[params_string.split('&').collect {|p| p.split('=')}]
    params
  end

  def get_response(url, params)
    RestClient::Request.execute(:method => :post, :url => url, :payload => params, :timeout => -1) { |response, request, result, &block|
      # check for error response
      lines = response.split("\n")
      first_line = lines.first.to_s.upcase
      case
      when first_line.include?('BAD_PASSWORD')
        raise OrgAccountInvalidCredentialsError, I18n.t('data_server.invalid_username_password', org: @org)
      when response.code.to_i == 500 || first_line.include?('ERROR') || first_line.include?('HTML')
        raise DataServerError, response
      end
      response = response.to_str.unpack("C*").pack("U*")
      # Strip annoying extra unicode at the beginning of the file
      response = response[3..-1] if response.first.localize.code_points.first == 239

      # look for a redirect
      if lines[1] && lines[1].include?('RedirectQueryIni')
        raise Errors::UrlChanged, lines[1].split('=')[1]
      end

      response
    }
  end

  def add_or_update_primary_contact(account_list, user, line, donor_account)
    remote_id = "#{donor_account.account_number}-1"
    add_or_update_person(account_list, user, line, donor_account, remote_id, '')
  end

  def add_or_update_spouse(account_list, user, line, donor_account)
    remote_id = "#{donor_account.account_number}-2"
    add_or_update_person(account_list, user, line, donor_account, remote_id, 'SP_')
  end

  def add_or_update_person(account_list, user, line, donor_account, remote_id, prefix = '')
    organization = donor_account.organization
    master_person_from_source = organization.master_people.where('master_person_sources.remote_id' => remote_id.to_s).first
    person = donor_account.people.where(master_person_id: master_person_from_source.id).first if master_person_from_source

    person ||= Person.new({master_person: master_person_from_source}, without_protection: true)
    person.attributes = {first_name: line[prefix + 'FIRST_NAME'], last_name: line[prefix + 'LAST_NAME'], middle_name: line[prefix + 'MIDDLE_NAME'],
                          title: line[prefix + 'TITLE'], suffix: line[prefix + 'SUFFIX'], gender: prefix.present? ? 'female' : 'male'}
    # Phone numbers
    person.phone_number = {'number' => line[prefix + 'PHONE']} if line[prefix + 'PHONE'].present? && line[prefix + 'PHONE'] != line[prefix + 'MOBILE_PHONE']
    person.phone_number = {'number' => line[prefix + 'MOBILE_PHONE'], 'location' => 'mobile'} if line[prefix + 'MOBILE_PHONE'].present?

    # email address
    person.email = line[prefix + 'EMAIL'] if line[prefix + 'EMAIL'] && line[prefix + 'EMAIL_VALID'] != 'FALSE'
    person.master_person_id ||= MasterPerson.find_or_create_for_person(person, donor_account: donor_account).try(:id)
    person.save!

    donor_account.people << person unless donor_account.people.include?(person)
    donor_account.master_people << person.master_person unless donor_account.master_people.include?(person.master_person)

    contact = account_list.contacts.for_donor_account(donor_account).first
    contact_person = contact.add_person(person)

    # create the master_person_source if needed
    unless master_person_from_source
      Retryable.retryable do
        organization.master_person_sources.where(remote_id: remote_id.to_s).first_or_create({master_person_id: person.master_person.id}, without_protection: true)
      end
    end

    [person, contact_person]
  end

  def add_or_update_company(account_list, user, line, donor_account)
    master_company = MasterCompany.find_by_name(line['LAST_NAME_ORG'])
    company = user.partner_companies.where(master_company_id: master_company.id).first if master_company

    company ||= account_list.companies.new({master_company: master_company}, without_protection: true)
    company.assign_attributes( {name: line['LAST_NAME_ORG'],
                                phone_number: line['PHONE'],
                                street: [line['ADDR1'], line['ADDR2'], line['ADDR3'], line['ADDR4']].select {|a| a.present?}.join("\n"),
                                city: line['CITY'],
                                state: line['STATE'],
                                postal_code: line['ZIP'],
                                country: line['CNTRY_DESCR']}, without_protection: true )
    company.save!
    donor_account.update_attributes(master_company_id: company.master_company_id) unless donor_account.master_company_id == company.master_company.id
    company
  end

  def add_or_update_donor_account(line, profile, account_list = nil)
    account_list ||= get_account_list(profile)
    donor_account = Retryable.retryable do
      donor_account = @org.donor_accounts.where(account_number: line['PEOPLE_ID']).first_or_initialize
      donor_account.attributes = {name: line['ACCT_NAME'],
                                  donor_type: line['PERSON_TYPE'] == 'P' ? 'Household' : 'Organization'} # if the acccount already existed, update the name
      # physical address
      if [line['ADDR1'],line['ADDR2'],line['ADDR3'],line['ADDR4'],line['CITY'],line['STATE'],line['ZIP'],line['CNTRY_DESCR']].any?(&:present?)
        donor_account.addresses_attributes = [{
                                                street: [line['ADDR1'], line['ADDR2'], line['ADDR3'], line['ADDR4']].select {|a| a.present?}.join("\n"),
                                                city: line['CITY'],
                                                state: line['STATE'],
                                                postal_code: line['ZIP'],
                                                country: line['CNTRY_DESCR']
                                              }]
      end
      donor_account.save!
      donor_account
    end
    contact = donor_account.link_to_contact_for(account_list)
    raise 'Failed to link to contact' unless contact
    donor_account
  end

  def find_or_create_designation_account(number, profile, extra_attributes = {})
    @designation_accounts ||= {}
    unless @designation_accounts.has_key?(number)
      da = Retryable.retryable do
        @org.designation_accounts.where(designation_number: number).first_or_create
      end
      profile.designation_accounts << da unless profile.designation_accounts.include?(da)
      da.update_attributes(extra_attributes, without_protection: true) if extra_attributes.present?
      @designation_accounts[number] = da
    end
    @designation_accounts[number]
  end

  def add_or_update_donation(line, designation_account, profile)
    default_currency = @org.default_currency_code || 'USD'
    donor_account = add_or_update_donor_account(line, profile)

    Retryable.retryable do
      donation = designation_account.donations.where(remote_id: line['DONATION_ID']).first_or_initialize
      date = line['DISPLAY_DATE'] ? Date.strptime(line['DISPLAY_DATE'], '%m/%d/%Y') : nil
      donation.assign_attributes( {
        donor_account_id: donor_account.id,
        motivation: line['MOTIVATION'],
        payment_method: line['PAYMENT_METHOD'],
        tendered_currency: line['TENDERED_CURRENCY'] || default_currency,
        memo: line['MEMO'],
        donation_date: date,
        amount: line['AMOUNT'],
        tendered_amount: line['TENDERED_AMOUNT'] || line['AMOUNT'],
        currency: default_currency
      }, without_protection: true )
      donation.save!
      donation
    end
  end
end

class OrgAccountMissingCredentialsError < StandardError
end
class OrgAccountInvalidCredentialsError < StandardError
end
class DataServerError < StandardError
end
