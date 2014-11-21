class TntImport
  # Donation Services seems to pad donor accounts with zeros up to length 9. TntMPD does not though.
  DONOR_NUMBER_NORMAL_LEN = 9

  def initialize(import)
    @import = import
    @account_list = @import.account_list
    @user = @import.user
    @designation_profile = @account_list.designation_profiles.first || @user.designation_profiles.first
    @tags_by_contact_id = {}
  end

  def read_xml(import_file)
    xml = {}
    begin
      File.open(import_file, 'r:utf-8') do |file|
        @contents = file.read
        begin
          xml = Hash.from_xml(@contents)
        rescue => e
          # If the document contains characters that we don't know how to parse
          # just strip them out.
          # The eval is dirty, but it was all I could come up with at the time
          # to unescape a unicode character.
          begin
            bad_char = e.message.match(/"([^"]*)"/)[1]
            @contents.gsub!(eval(%("#{bad_char}")), ' ') # rubocop:disable Eval
          rescue
            raise e
          end
          retry
        end
      end
    rescue ArgumentError
      File.open(import_file, 'r:windows-1251:utf-8') do |file|
        xml = Hash.from_xml(file.read)
      end
    end
    xml
  end

  def xml
    unless @xml
      @xml = read_xml(@import.file.file.file)
      if @xml.present? && @xml['Database']
        @xml = @xml['Database']['Tables']
      else
        @xml = nil
      end
    end
    @xml
  end

  def import
    @import.file.cache_stored_file!

    if xml.present?
      tnt_contacts = import_contacts
      import_tasks(tnt_contacts)
      import_history(tnt_contacts)
      import_settings
    end

  ensure
    CarrierWave.clean_cached_files!
  end

  private

  def load_contact_group_tags
    @tags_by_contact_id = {}

    return unless xml['Group']

    groups = Array.wrap(xml['Group']['row']).map do |row|
      { id: row['id'], category: row['Category'],
        description: row['Category'] ? row['Description'].sub("#{row['Category']}\\", '') : row['Description'] }
    end
    groups_by_id = Hash[groups.map { |group| [group[:id], group] }]

    Array.wrap(xml['GroupContact']['row']).each do |row|
      group = groups_by_id[row['GroupID']]
      tags = [group[:description].gsub(' ', '-')]
      tags << group[:category].gsub(' ', '-') if group[:category]

      tags_list = @tags_by_contact_id[row['ContactID']]
      tags_list ||= []
      tags_list += tags
      @tags_by_contact_id[row['ContactID']] = tags_list
    end
  end

  def import_contacts
    @tnt_contacts = {}

    load_contact_group_tags

    rows = Array.wrap(xml['Contact']['row'])

    rows.each_with_index do |row, _i|

      contact = Retryable.retryable do
        @account_list.contacts.where(tnt_id: row['id']).first
      end

      donor_accounts = add_or_update_donor_accounts(row, @designation_profile)

      donor_accounts.each do |donor_account|
        contact = donor_account.link_to_contact_for(@account_list, contact)
      end

      # Look for more ways to link a contact
      contact ||= Retryable.retryable do
        @account_list.contacts.where(name: row['FileAs']).first_or_create
      end

      # add additional data to contact
      update_contact(contact, row)

      primary_contact_person = add_or_update_primary_person(row, contact)

      # Now the secondary person (persumably spouse)
      if row['SpouseFirstName'].present?
        row['SpouseLastName'] = row['LastName'] if row['SpouseLastName'].blank?
        contact_spouse = add_or_update_spouse(row, contact)

        # Wed the two peple
        primary_contact_person.add_spouse(contact_spouse)
      end

      merge_dups_by_donor_accts(contact, donor_accounts) if @import.override?

      @tnt_contacts[row['id']] = contact

      next unless true?(row['IsOrganization'])
      # organization
      donor_accounts.each do |donor_account|
        add_or_update_company(row, donor_account)
      end
    end

    # set referrals
    # Loop over the whole list again now that we've added everyone and try to link up referrals
    rows.each do |row|
      referred_by = @tnt_contacts.find { |_tnt_id, c|
        c.name == row['ReferredBy'] ||
        c.full_name == row['ReferredBy'] ||
        c.greeting == row['ReferredBy']
      }
      next unless referred_by
      contact = @tnt_contacts[row['id']]
      contact.referrals_to_me << referred_by[1] unless contact.referrals_to_me.include?(referred_by[1])
    end

    @tnt_contacts
  end

  # If the user had two donor accounts in the same contact in Tnt, then  merge different contacts with those in MPDX.
  def merge_dups_by_donor_accts(tnt_contact, donor_accounts)
    @account_list.contacts.where.not(id: tnt_contact.id).joins(:donor_accounts)
      .where(donor_accounts: { id: donor_accounts.map(&:id) }).readonly(false)
      .each do |dup_contact_matching_donor_account|

      tnt_contact.reload.merge(dup_contact_matching_donor_account)
    end
  end

  def import_tasks(tnt_contacts = {})
    tnt_tasks = {}

    Array.wrap(xml['Task']['row']).each do |row|
      task = Retryable.retryable do
        @account_list.tasks.where(remote_id: row['id'], source: 'tnt').first_or_initialize
      end

      task.attributes = {
        activity_type: lookup_task_type(row['TaskTypeID']),
        subject: row['Description'],
        start_at: DateTime.parse(row['TaskDate'] + ' ' + DateTime.parse(row['TaskTime']).strftime('%I:%M%p'))
      }
      next unless task.save
      # Add any notes as a comment
      task.activity_comments.create(body: row['Notes'].strip) if row['Notes'].present?
      tnt_tasks[row['id']] = task
    end

    # Add contacts to tasks
    Array.wrap(xml['TaskContact']['row']).each do |row|
      next unless tnt_contacts[row['ContactID']] && tnt_tasks[row['TaskID']]
      tnt_tasks[row['TaskID']].contacts << tnt_contacts[row['ContactID']] unless tnt_tasks[row['TaskID']].contacts.include? tnt_contacts[row['ContactID']]
    end

    tnt_tasks
  end

  def import_history(tnt_contacts = {})
    tnt_history = {}

    Array.wrap(xml['History']['row']).each do |row|
      task = Retryable.retryable do
        @account_list.tasks.where(remote_id: row['id'], source: 'tnt').first_or_initialize
      end

      task.attributes = {
        activity_type: lookup_task_type(row['TaskTypeID']),
        subject: row['Description'] || lookup_task_type(row['TaskTypeID']),
        start_at: DateTime.parse(row['HistoryDate']),
        completed_at: DateTime.parse(row['HistoryDate']),
        completed: true,
        result: lookup_history_result(row['HistoryResultID'])
      }
      next unless task.save
      # Add any notes as a comment
      task.activity_comments.create(body: row['Notes'].strip) if row['Notes'].present?
      tnt_history[row['id']] = task
    end

    # Add contacts to tasks
    Array.wrap(xml['HistoryContact']['row']).each do |row|
      next unless tnt_contacts[row['ContactID']] && tnt_history[row['HistoryID']]
      Retryable.retryable times: 3, sleep: 1 do
        tnt_history[row['HistoryID']].contacts << tnt_contacts[row['ContactID']] unless tnt_history[row['HistoryID']].contacts.include? tnt_contacts[row['ContactID']]
      end
    end

    tnt_history
  end

  def import_settings
    Array.wrap(xml['Property']['row']).each do |row|
      case row['PropName']
      when 'MonthlySupportGoal'
        @account_list.monthly_goal = row['PropValue'] if @import.override? || @account_list.monthly_goal.blank?
      when 'MailChimpListId'
        @mail_chimp_list_id = row['PropValue']
      when 'MailChimpAPIKey'
        @mail_chimp_key = row['PropValue']
      end

      create_or_update_mailchimp(@mail_chimp_list_id, @mail_chimp_key) if @mail_chimp_list_id && @mail_chimp_key
    end
    @account_list.save
  end

  def create_or_update_mailchimp(mail_chimp_list_id, mail_chimp_key)
    if @account_list.mail_chimp_account
      if @import.override?
        @account_list.mail_chimp_account.update_attributes(api_key: mail_chimp_key,
                                                           primary_list_id: mail_chimp_list_id)
      end
    else
      @account_list.create_mail_chimp_account(api_key: mail_chimp_key,
                                              primary_list_id: mail_chimp_list_id)
    end
  end

  def update_contact(contact, row)
    contact.name = row['FileAs'] if @import.override? || contact.name.blank?
    contact.full_name = row['FullName'] if @import.override? || contact.full_name.blank?
    contact.greeting = row['Greeting'] if @import.override? || contact.greeting.blank?
    contact.website = row['WebPage'] if @import.override? || contact.website.blank?
    contact.updated_at = parse_date(row['LastEdit']) if @import.override?
    contact.created_at = parse_date(row['CreatedDate']) if @import.override?
    contact.notes = row['Notes'] if @import.override? || contact.notes.blank?
    contact.pledge_amount = row['PledgeAmount'] if @import.override? || contact.pledge_amount.blank?
    contact.pledge_frequency = row['PledgeFrequencyID'] if (@import.override? || contact.pledge_frequency.blank?) && row['PledgeFrequencyID'].to_i != 0
    contact.pledge_start_date = parse_date(row['PledgeStartDate']) if (@import.override? || contact.pledge_start_date.blank?) && row['PledgeStartDate'].present?
    contact.pledge_received = true?(row['PledgeReceived']) if @import.override? || contact.pledge_received.blank?
    contact.status = lookup_mpd_phase(row['MPDPhaseID']) if (@import.override? || contact.status.blank?) && lookup_mpd_phase(row['MPDPhaseID']).present?
    contact.next_ask = parse_date(row['NextAsk']) if (@import.override? || contact.next_ask.blank?) && row['NextAsk'].present?
    contact.likely_to_give = contact.assignable_likely_to_gives[row['LikelyToGiveID'].to_i - 1] if (@import.override? || contact.likely_to_give.blank?) && row['LikelyToGiveID'].to_i != 0
    contact.never_ask = true?(row['NeverAsk']) if @import.override? || contact.never_ask.blank?
    contact.church_name = row['ChurchName'] if @import.override? || contact.church_name.blank?

    if (@import.override? || contact.send_newsletter.blank?) && true?(row['SendNewsletter'])
      case row['NewsletterMediaPref']
      when '+E', '+E-P'
        contact.send_newsletter = 'Email'
      when '+P', '+P-E'
        contact.send_newsletter = 'Physical'
      else
        contact.send_newsletter = 'Both'
      end
    end

    contact.direct_deposit = true?(row['DirectDeposit']) if @import.override? || contact.direct_deposit.blank?
    contact.magazine = true?(row['Magazine']) if @import.override? || contact.magazine.blank?
    contact.last_activity = parse_date(row['LastActivity']) if (@import.override? || contact.last_activity.blank?) && row['LastActivity'].present?
    contact.last_appointment = parse_date(row['LastAppointment']) if (@import.override? || contact.last_appointment.blank?) && row['LastAppointment'].present?
    contact.last_letter = parse_date(row['LastLetter']) if (@import.override? || contact.last_letter.blank?) && row['LastLetter'].present?
    contact.last_phone_call = parse_date(row['LastCall']) if (@import.override? || contact.last_phone_call.blank?) && row['LastCall'].present?
    contact.last_pre_call = parse_date(row['LastPreCall']) if (@import.override? || contact.last_pre_call.blank?) && row['LastPreCall'].present?
    contact.last_thank = parse_date(row['LastThank']) if (@import.override? || contact.last_thank.blank?) && row['LastThank'].present?
    contact.tag_list.add(@import.tags, parse: true) if @import.tags.present?
    contact.tnt_id = row['id']
    contact.addresses_attributes = build_address_array(row, contact, @import.override)

    tags = @tags_by_contact_id[row['id']]
    tags.each { |tag| contact.tag_list.add(tag) } if tags

    contact.save
  end

  def true?(val)
    val.upcase == 'TRUE'
  end

  def parse_date(val)
    Date.parse(val)
  rescue
  end

  def lookup_mpd_phase(phase)
    case phase.to_i
    when 10 then 'Never Contacted'
    when 20 then 'Ask in Future'
    when 30 then 'Contact for Appointment'
    when 40 then 'Appointment Scheduled'
    when 50 then 'Call for Decision'
    when 60 then 'Partner - Financial'
    when 70 then 'Partner - Special'
    when 80 then 'Partner - Pray'
    when 90 then 'Not Interested'
    when 95 then 'Unresponsive'
    when 100 then 'Never Ask'
    when 110 then 'Research Abandoned'
    when 130 then 'Expired Referral'
    end
  end

  def lookup_task_type(task_type_id)
    case task_type_id.to_i
    when 1 then 'Appointment'
    when 2 then 'Thank'
    when 3 then 'To Do'
    when 20 then 'Call'
    when 30 then 'Reminder Letter'
    when 40 then 'Support Letter'
    when 50 then 'Letter'
    when 60 then 'Newsletter'
    when 70 then 'Pre Call Letter'
    when 100 then 'Email'
    end
  end

  def lookup_history_result(history_result_id)
    case history_result_id.to_i
    when 1 then 'Done'
    when 2 then 'Received'
    when 3 then 'Attempted'
    end
  end

  def add_or_update_company(row, donor_account)
    master_company = MasterCompany.find_by_name(row['OrganizationName'])
    company = @user.partner_companies.where(master_company_id: master_company.id).first if master_company

    company ||= @account_list.companies.new(master_company: master_company)
    company.assign_attributes(name: row['OrganizationName'],
                              phone_number: row['Phone'],
                              street: row['MailingStreetAddress'],
                              city: row['MailingCity'],
                              state: row['MailingState'],
                              postal_code: row['MailingPostalCode'],
                              country: row['MailingCountry'])
    company.save!
    donor_account.update_attribute(:master_company_id, company.master_company_id) unless donor_account.master_company_id == company.master_company.id
    company
  end

  def add_or_update_primary_person(row, contact)
    add_or_update_person(row, contact)
  end

  def add_or_update_spouse(row, contact)
    add_or_update_person(row, contact, 'Spouse')
  end

  def add_or_update_person(row, contact, prefix = '')
    row[prefix + 'FirstName'] = 'Unknown' if row[prefix + 'FirstName'].blank?

    # See if there's already a person by this name on this contact (This is a contact with multiple donation accounts)
    person = contact.people.where(first_name: row[prefix + 'FirstName'], last_name: row[prefix + 'LastName'])
                           .where("middle_name = ? OR middle_name = '' OR middle_name is NULL", row[prefix + 'MiddleName']).first
    person ||= Person.new

    update_person_attributes(person, row, prefix)

    person.master_person_id ||= MasterPerson.find_or_create_for_person(person).id

    person.save(validate: false)

    begin
      contact.people << person unless contact.people.include?(person)
    rescue ActiveRecord::RecordNotUnique
    end

    person
  end

  def update_person_attributes(person, row, prefix = '')
    person.attributes = { first_name: row[prefix + 'FirstName'], last_name: row[prefix + 'LastName'], middle_name: row[prefix + 'MiddleName'],
                          title: row[prefix + 'Title'], suffix: row[prefix + 'Suffix'], gender: prefix.present? ? 'female' : 'male',
                          profession: prefix.present? ? nil : row['Profession'] }
    # Phone numbers
    phone_number_locations =
    { 'HomePhone' => 'home', 'HomePhone2' => 'home', 'HomeFax' => 'fax',
      prefix + 'BusinessPhone' => 'work', prefix + 'BusinessPhone2' => 'work',
      prefix + 'BusinessFax' => 'fax', prefix + 'CompanyMainPhone' => 'work',
      'AssistantPhone' => 'work', 'OtherPhone' => 'other', 'CarPhone' => 'mobile',
      prefix + 'MobilePhone' => 'mobile', prefix + 'MobilePhone2' => 'mobile',
      prefix + 'PagerNumber' => 'other', 'CallbackPhone' => 'other',
      'ISDNPhone' => 'other', 'PrimaryPhone' => 'other', 'RadioPhone' => 'other',
      'TelexPhone' => 'other' }
    phone_number_locations.each_with_index do |key, i|
      person.phone_number = { number: row[key[0]], location: key[1], primary: row['PreferredPhoneType'].to_i == i } if row[key[0]].present?
    end

    # email address
    3.times do |i|
      person.email_address = { email: row[prefix + "Email#{i}"], primary: row['PreferredEmailTypes'] == i } if row[prefix + "Email#{i}"].present?
    end

    person
  end

  def add_or_update_donor_accounts(row, designation_profile)
    # create variables outside the block scope
    donor_accounts = []

    if designation_profile
      donor_accounts = row['OrgDonorCodes'].to_s.split(',').map do |account_number|
        donor_account = Retryable.retryable do
          da = designation_profile.organization.donor_accounts
            .where('account_number = :account_number OR account_number = :padded_account_number',
                   account_number: account_number,
                   padded_account_number: account_number.rjust(DONOR_NUMBER_NORMAL_LEN, '0')).first

          unless da
            da = designation_profile.organization.donor_accounts.new(account_number: account_number, name: row['FileAs'])
            da.addresses_attributes = build_address_array(row)
            da.save!
          end
          da
        end
        donor_account
      end
    end

    donor_accounts
  end

  def build_address_array(row, contact = nil, override = true)
    addresses = []
    %w(Home Business Other).each_with_index do |location, i|
      street = row["#{location}StreetAddress"]
      city = row["#{location}City"]
      state = row["#{location}State"]
      postal_code = row["#{location}PostalCode"]
      country = row["#{location}Country"] == 'United States of America' ? 'United States' : row["#{location}Country"]
      next unless [street, city, state, postal_code].any?(&:present?)
      primary_address = false
      primary_address = row['MailingAddressType'].to_i == (i + 1) if override
      if primary_address && contact
        contact.addresses.each do |address|
          next if address.street == street && address.city == city && address.state == state && address.postal_code == postal_code && address.country == country
          address.primary_mailing_address = false
          address.save
        end
      end
      addresses << {
        street: street,
        city: city,
        state: state,
        postal_code: postal_code,
        country: country,
        location: location,
        region: row['Region'],
        primary_mailing_address: primary_address
      }
    end
    addresses
  end
end
