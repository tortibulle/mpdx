class Siebel < DataServer

  def import_profile_balance(profile)
    # update account balance for each account associated with this profile
    profile.designation_accounts.each do |da|
      data = get_response("accounts/#{da.designation_number}/balance", da.designation_number)

      da.update_attributes({balance_updated_at: data['effectiveDate'],
                            balance: data['balance']})
    end
    true
  end

  def import_donors(date_from = nil)
    user = @org_account.user

    account_list = get_account_list

    # Fetch JSON data
    data = get_response("desigdata/#{@org_account.remote_id}/donors")

    if data.present?
      data.each do |line|
        Person.transaction do
          donor_account = add_or_update_donor_account(line, profile)

          unless %w{Household Organization Church Company}.include?(line['type'])
            Airbrake.notify(
              error_class: "Unknown TYPE",
              error_message: "Unknown TYPE: #{line['type']}",
              parameters: {line: line, org: @org.inspect, user: @user.inspect, org_account: @org_account.inspect}
            )
            line['type'] = 'Company'
          end

          case line['type']
          when 'Household'

            # Create/Update primary contact
            primary_contact = add_or_update_primary_contact(account_list, user, line['primary'], donor_account)

            # Add Spouse if there is
            if line['spouse'].present?
              spouse = add_or_update_spouse(account_list, user, line['spouse'], donor_account)
              # Wed the two peple
              primary_contact.add_spouse(spouse)
            end
          when 'Church', 'Organization', 'Company'
            add_or_update_company(account_list, user, line['primary'], donor_account)
          end
        end
      end
    end
    true
  end

  def import_donations(start_date, end_date, donor = nil)
    parameters = "?start_date=#{start_date}&end_date=#{end_date}"
    parameters += "&donor=#{donor}"
    profile = @org_account
    user = profile.person.to_user

    account_list = @org.designation_accounts.collect {|da| da.account_list(user)}.first
    account_list ||= user.account_lists.first

    # Fetch JSON data
    data = get_response("desigdata/#{@org_account.remote_id}/donations")

    if data.present?
      data.each do |line|
        designation_account = find_or_create_designation_account(profile,line['designation'])
        add_or_update_donation(line, designation_account, profile)
      end
    end
    true
  end

  def get_response(url, id = @org_account.remote_id, extra = {})
    url = "#{API_URL}/#{url}"

    RestClient::Request.execute(method: :get, url: url, payload: extra, timeout: -1, headers: {'Authorization' => "Bearer #{@org_account.token}"}) { |response, request, result, &block|
      # check for error response
      if response.code.to_i == 500
        raise DataServerError, response.inspect
      end
      JSON.parse(response.to_str)
    }
  end

  protected

  def profiles
    unless @profiles
      @profiles = []
      data = get_response("profiles/#{@org_account.remote_id}/list")
      data.each do |profile_data|
        @profiles << {name: profile_data['name'], conde: profile_data['code']}
      end
    end
    @profiles
  end

  def find_or_create_designation_profile(profile, hash) 
    profile = @org.designation_profiles.where(user_id: profile.person_id,
                                              name: hash['name'],
                                              remote_id: hash['id']).first_or_create 
    profile
  end

  def link_profile_to_account(designation_profile,designation_account)
    DesignationProfileAccount.where(designation_profile_id: designation_profile.id,
                                    designation_account_id: designation_account.id).first_or_create
  end

  def find_or_create_designation_account(profile, number, extra_attributes = {})
    @designation_accounts ||= {}
    unless @designation_accounts.has_key?(number)
      da = @org.designation_accounts.where(designation_number: number).first_or_create
      @org.designation_accounts << da unless @org.designation_accounts.include?(da)
      da.update_attributes(extra_attributes) if extra_attributes.present?
      @designation_accounts[number] = da
    end
    @designation_accounts[number]
  end

  def add_or_update_donation(line, designation_account, profile)
    default_currency = @org.default_currency_code || 'USD'
    donor_account = add_or_update_donor_account(line, profile)
    donation = designation_account.donations.where(remote_id: line['id']).first_or_initialize
    Rails.logger.info "Resultssss: #{donation.to_json}"
    date = line['donationDate'] ? Date.strptime(line['donationDate'], '%Y-%m-%d') : nil
    donation.attributes = {
      donor_account_id: donor_account.id,
      motivation: line['campaignCode'],
      payment_method: line['paymentMethod'],
      tendered_currency: default_currency,
      donation_date: date,
      amount: line['amount'],
      tendered_amount: line['amount'],
      currency: default_currency,
      channel: line['channel'],
      payment_type: line['paymentType']
    }
    donation.save!
    donation
  end

  def add_or_update_primary_contact(account_list, user, line, donor_account)
    remote_ids = ["#{donor_account.account_number}-1", line['id']]
    add_or_update_person(account_list, user, line, donor_account, remote_ids)
  end

  def add_or_update_spouse(account_list, user, line, donor_account)
    remote_ids = ["#{donor_account.account_number}-2", line['id']]
    add_or_update_person(account_list, user, line, donor_account, remote_ids)
  end

  def add_or_update_company(account_list, user, line, donor_account)
    master_company = MasterCompany.find_by_name(line['accountName'])
    company = user.partner_companies.where(master_company_id: master_company.id).first if master_company
    company ||= account_list.companies.new({master_company: master_company}, without_protection: true)

    # contacts
    phone_numbers = line['primary']['phoneNumbers']
    phone_number = nil
    if phone_numbers
      phone_numbers.each do |p|
        phone_number = p['phone'] if p['primary']
      end
    end

    # addresses
    addresses = line['addresses']
    street = nil
    city = nil
    state = nil
    postal_code = nil
    if addresses
      addresses.each do |a|
        if a['primary']
          street = [a['address1'], a['address2'], a['address3'], a['address4']].select {|a| a.present?}.join("\n")
          city = a['city']
          state = a['state']
          postal_code = a['zip']
        end
      end
    end
    company.attributes = {
      name: line['accountName'],
      phone_number: phone_number,
      street: street,
      city: city,
      state: state,
      postal_code: postal_code
    }
    company.save!
    donor_account.update_attribute(:master_company_id, company.master_company_id) unless donor_account.master_company_id == company.master_company.id
    company
  end

  def add_or_update_donor_account(line, profile)
    account_list = @org_account.user.account_lists.where(designation_profile_id: profile.id).first
    donor_account = @org.donor_accounts.where(account_number: line['id']).first_or_create(name: line['accountName'])
    donor_account.name = line['accountName']

    # Save Primary Address
    if line['addresses']
      addresses = line['addresses']
      street = nil
      city = nil
      state = nil
      postal_code = nil

      addresses.each do |a|
        if a['primary']
          street = [a['address1'], a['address2'], a['address3'], a['address4']].select {|a| a.present?}.join("\n")
          city = a['city']
          state = a['state']
          postal_code = a['zip']
        end
      end

      donor_account.addresses_attributes = {'0' => 
                                            {
                                              street: street,
                                              city: city,
                                              state: state,
                                              postal_code: postal_code
                                            }
      }

      donor_account.save!
      contact = donor_account.link_to_contact_for(account_list)
      raise 'Failed to link to contact' unless contact
    end
    donor_account
  end

  def add_or_update_person(account_list, user, line, donor_account, remote_id)
    organization = donor_account.organization
    master_person_from_source = organization.master_people.where('master_person_sources.remote_id' => remote_id).first
    person = donor_account.people.where(master_person_id: master_person_from_source.id).first if master_person_from_source

    person ||= Person.new({master_person: master_person_from_source}, without_protection: true)

    person.attributes = {
      first_name: line['firstName'],
      last_name: line['lastName'],
      middle_name: line['middleName'],
      title: line['title'],
      suffix: line['suffix']
    }

    # Phone Numbers
    if line['phoneNumbers'].present?
      line['phoneNumbers'].each do |line_phone_number|
        if line_phone_number['phone'].present?
          person.phone_number = {
                                  number: line_phone_number['phone'],
                                  location: line_phone_number['type'].downcase,
                                  primary: line_phone_number['primary'] ? 1 : 0
                                }
        end
      end
    end

    # Email Address
    if line['emailAddresses'].present?
      line['emailAddresses'].each do |line_email|
        if line_email['email'].present? # && line_email['type'].present?
          # person.email = line_email['email']
          person.email_address = {
            email: line_email['email'],
            primary: line_email['primary'] ? 1 : 0
          }
        end
      end
    end

    person.master_person_id ||= MasterPerson.find_or_create_for_person(person, donor_account: donor_account).try(:id)
    person.save!

    donor_account.master_people << person.master_person unless donor_account.master_people.include?(person.master_person)

    contact = account_list.contacts.where(donor_account_id: donor_account.id).first
    contact_person = contact.add_person(person)

    # create the master_person_source if needed
    unless master_person_from_source
      organization.master_person_sources.where(remote_id: remote_id).first_or_create(master_person_id: person.master_person.id)
    end

    [person, contact_person]
  end

  def check_credentials!() end

end


class OrgAccountMissingCredentialsError < StandardError
end
class OrgAccountInvalidCredentialsError < StandardError
end
class SiebelError < StandardError
end
