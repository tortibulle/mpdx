class TntImport

  def initialize(import)
    @import = import
    @account_list = @import.account_list
    @user = @import.user
    @designation_profile = @account_list.designation_profiles.first || @user.designation_profiles.first
  end

  def read_xml(import_file)
    xml = {}
    begin
      File.open(import_file, "r:utf-8") do |file|
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
            subbed = @contents.gsub!(eval(%Q{"#{bad_char}"}), " ")
          rescue => new_error
            raise e
          end
          retry
        end
      end
    rescue ArgumentError
      File.open(import_file, "r:windows-1251:utf-8") do |file|
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

  def import_contacts

    @tnt_contacts = {}

    rows = Array.wrap(xml['Contact']['row'])

    rows.each_with_index do |row, i|

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

      @tnt_contacts[row['id']] = contact

      if is_true?(row['IsOrganization'])
        # organization
        donor_accounts.each do |donor_account|
          add_or_update_company(row, donor_account)
        end
      end
    end

    # set referrals
    # Loop over the whole list again now that we've added everyone and try to link up referrals
    rows.each do |row|
      if referred_by = @tnt_contacts.detect {|tnt_id, c| c.name == row['ReferredBy'] ||
                                                         c.full_name == row['ReferredBy'] ||
                                                         c.greeting == row['ReferredBy'] }
        contact = @tnt_contacts[row['id']]
        contact.referrals_to_me << referred_by[1] unless contact.referrals_to_me.include?(referred_by[1])
      end
    end

    @tnt_contacts
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
                         start_at: DateTime.parse(row['TaskDate'] + ' ' + DateTime.parse(row['TaskTime']).strftime("%I:%M%p"))
                        }
      if task.save
        # Add any notes as a comment
        if row['Notes'].present?
          task.activity_comments.create(body: row['Notes'].strip)
        end

        tnt_tasks[row['id']] = task
      end
    end

    # Add contacts to tasks
    Array.wrap(xml['TaskContact']['row']).each do |row|
      if tnt_contacts[row['ContactID']] && tnt_tasks[row['TaskID']]
        tnt_tasks[row['TaskID']].contacts << tnt_contacts[row['ContactID']] unless tnt_tasks[row['TaskID']].contacts.include? tnt_contacts[row['ContactID']]
      end
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
      if task.save
        # Add any notes as a comment
        if row['Notes'].present?
          task.activity_comments.create(body: row['Notes'].strip)
        end

        tnt_history[row['id']] = task
      end
    end

    # Add contacts to tasks
    Array.wrap(xml['HistoryContact']['row']).each do |row|
      if tnt_contacts[row['ContactID']] && tnt_history[row['HistoryID']]
        Retryable.retryable :times => 3, :sleep => 1 do
          tnt_history[row['HistoryID']].contacts << tnt_contacts[row['ContactID']] unless tnt_history[row['HistoryID']].contacts.include? tnt_contacts[row['ContactID']]
        end
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
    if @import.override? || contact.notes.blank?
      contact.notes = begin
                        Nokogiri::HTML(RubyRTF::Parser.new.parse(row['Notes'].to_s).sections.collect {|s| s[:text]}.join("\n").gsub(/\n+/, "\n")).text
                      rescue RubyRTF::InvalidDocument, NoMethodError
                        row['Notes']
                      end.to_s.unpack("C*").pack("U*").force_encoding("UTF-8").encode!
    end
    contact.pledge_amount = row['PledgeAmount'] if @import.override? || contact.pledge_amount.blank?
    contact.pledge_frequency = row['PledgeFrequencyID'] if (@import.override? || contact.pledge_frequency.blank?) && row['PledgeFrequencyID'].to_i != 0
    contact.pledge_start_date = parse_date(row['PledgeStartDate']) if (@import.override? || contact.pledge_start_date.blank?) && row['PledgeStartDate'].present?
    contact.pledge_received = is_true?(row['PledgeReceived']) if @import.override? || contact.pledge_received.blank?
    contact.status = lookup_mpd_phase(row['MPDPhaseID']) if (@import.override? || contact.status.blank?) && lookup_mpd_phase(row['MPDPhaseID']).present?
    contact.next_ask = parse_date(row['NextAsk']) if (@import.override? || contact.next_ask.blank?) && row['NextAsk'].present?
    contact.likely_to_give = contact.assignable_likely_to_gives[row['LikelyToGiveID'].to_i - 1] if (@import.override? || contact.likely_to_give.blank?) && row['LikelyToGiveID'].to_i != 0
    contact.never_ask = is_true?(row['NeverAsk']) if @import.override? || contact.never_ask.blank?
    contact.church_name = row['ChurchName'] if @import.override? || contact.church_name.blank?
    if (@import.override? || contact.send_newsletter.blank?) && is_true?(row['SendNewsletter'])
      case row['NewsletterMediaPref']
      when '+E'
        contact.send_newsletter = 'Email'
      when '+P'
        contact.send_newsletter = 'Physical'
      else
        contact.send_newsletter = 'Both'
      end
    end
    contact.direct_deposit = is_true?(row['DirectDeposit']) if @import.override? || contact.direct_deposit.blank?
    contact.magazine = is_true?(row['Magazine']) if @import.override? || contact.magazine.blank?
    contact.last_activity = parse_date(row['LastActivity']) if (@import.override? || contact.last_activity.blank?) && row['LastActivity'].present?
    contact.last_appointment = parse_date(row['LastAppointment']) if (@import.override? || contact.last_appointment.blank?) && row['LastAppointment'].present?
    contact.last_letter = parse_date(row['LastLetter']) if (@import.override? || contact.last_letter.blank?) && row['LastLetter'].present?
    contact.last_phone_call = parse_date(row['LastPhoneCall']) if (@import.override? || contact.last_phone_call.blank?) && row['LastPhoneCall'].present?
    contact.last_pre_call = parse_date(row['LastPreCall']) if (@import.override? || contact.last_pre_call.blank?) && row['LastPreCall'].present?
    contact.last_thank = parse_date(row['LastThank']) if (@import.override? || contact.last_thank.blank?) && row['LastThank'].present?
    contact.tag_list.add(@import.tags, parse: true) if @import.tags.present?
    contact.tnt_id = row['id']
    contact.addresses_attributes = build_address_array(row)
    contact.save
  end

  def is_true?(val)
    val.upcase == 'TRUE'
  end

  def parse_date(val)
    begin
      Date.parse(val)
    rescue; end
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
    company.assign_attributes( name: row['OrganizationName'],
                               phone_number: row['Phone'],
                               street: row['MailingStreetAddress'],
                               city: row['MailingCity'],
                               state: row['MailingState'],
                               postal_code: row['MailingPostalCode'],
                               country: row['MailingCountry'] )
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
    person.attributes = {first_name: row[prefix + 'FirstName'], last_name: row[prefix + 'LastName'], middle_name: row[prefix + 'MiddleName'],
                          title: row[prefix + 'Title'], suffix: row[prefix + 'Suffix'], gender: prefix.present? ? 'female' : 'male',
                          profession: prefix.present? ? nil : row['Profession']}
    # Phone numbers
    {'HomePhone' => 'home', 'HomePhone2' => 'home', 'HomeFax' => 'fax',
     'BusinessPhone' => 'work', 'BusinessPhone2' => 'work', 'BusinessFax' => 'fax',
     'CompanyMainPhone' => 'work', 'AssistantPhone' => 'work', 'OtherPhone' => 'other',
     'CarPhone' => 'mobile', 'MobilePhone' => 'mobile', 'PagerNumber' => 'other',
     'CallbackPhone' => 'other', 'ISDNPhone' => 'other', 'PrimaryPhone' => 'other',
     'RadioPhone' => 'other', 'TelexPhone' => 'other'}.each_with_index do |key, i|
       person.phone_number = {number: row[key[0]], location: key[1], primary: row['PreferredPhoneType'].to_i == i} if row[key[0]].present?
     end

    # email address
    3.times do |i|
      person.email_address = {email: row["Email#{i}"], primary: row['PreferredEmailTypes'] == i} if row["Email#{i}"].present?
    end

    person
  end

  def add_or_update_donor_accounts(row, designation_profile)
    # create variables outside the block scope
    donor_accounts = []

    if designation_profile
      donor_accounts = row['OrgDonorCodes'].to_s.split(',').collect do |account_number|
        donor_account = Retryable.retryable do
          da = designation_profile.organization.donor_accounts.where(account_number: account_number).first
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

  def build_address_array(row)
    addresses = []
    %w[Home Business Other].each_with_index do |location, i|
      if [row["#{location}StreetAddress"],row["#{location}City"],row["#{location}State"],row["#{location}PostalCode"]].any?(&:present?)
        addresses << {
                        street: row["#{location}StreetAddress"],
                        city: row["#{location}City"],
                        state: row["#{location}State"],
                        postal_code: row["#{location}PostalCode"],
                        country: row["#{location}Country"],
                        location: location,
                        primary_mailing_address: row['PreferredAddressType'].to_i == (i + 1)
                      }
      end
    end

    addresses
  end

end
