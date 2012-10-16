class TntImport

  def initialize(import)
    @import = import
  end

  def get_lines(contents)
    # Strip annoying tnt unicode character
    contents = contents[1..-1] if contents.first.localize.code_points.first == 65279
    CSV.parse(contents, headers: true)
  rescue CSV::MalformedCSVError
    raise TwitterCldr::Utils::CodePoints.from_string(contents.first).inspect
  end

  def read_csv(import_file)
    lines = []
    begin
      File.open(import_file, "r:utf-8") do |file|
        lines = get_lines(file.read)
      end
    rescue ArgumentError
      File.open(import_file, "r:windows-1251:utf-8") do |file|
        lines = get_lines(file.read)
      end
    end
    lines
  end

  def import_contacts
    Contact.transaction do
      # we need to take some extra steps to get the file opened with the right encoding
      @import.file.cache_stored_file!

      lines = read_csv(@import.file.file.file)

      unless lines.first.headers.include?('Organization Account IDs')
        raise "export didn't include Organization Account IDs'"
      end

      account_list = @import.account_list
      user = @import.user
      designation_profile = account_list.designation_profile || user.designation_profiles.first

      tnt_contacts = {}

      lines.each do |line|
        donor_accounts, contact = add_or_update_donor_accounts(line, account_list, designation_profile)
        tnt_contacts[line['ContactID']] = contact

        # add additional data to contact
        update_contact(contact, line)

        unless is_true?(line['Is Organization'])
          # person
          donor_accounts.each do |donor_account|
            primary_person, primary_contact_person = add_or_update_primary_contact(account_list, user, line, donor_account, contact)

            # Now the secondary person (persumably spouse)
            if line['Spouse First/Given Name'].present?
              line['Spouse Last/Family Name'] = line['Last/Family Name'] if line['Spouse Last/Family Name'].blank?
              spouse, contact_spouse = add_or_update_spouse(account_list, user, line, donor_account, contact)

              # Wed the two peple
              primary_person.add_spouse(spouse)
              primary_contact_person.add_spouse(contact_spouse)
            end
            # TODO: handle children

          end
        else
          # organization
          donor_accounts.each do |donor_account|
            add_or_update_company(account_list, user, line, donor_account)
          end
        end
      end

      # set referrals
      # Loop over the whole list again now that we've added everyone and try to link up referrals
      lines.each do |line|
        if line['Referred By'].present? &&
           referred_by = account_list.contacts.where("name = ? OR full_name = ? OR greeting = ?",
                                                      line['Referred By'], line['Referred By'], line['Referred By']).first
          contact = tnt_contacts[line['ContactID']]
          contact.referrals_to_me << referred_by unless contact.referrals_to_me.include?(referred_by)
        end
      end
    end
  ensure
    @file.close if @file
    CarrierWave.clean_cached_files!
  end

  private

  def update_contact(contact, line)
    contact.full_name = line['Full Name'] if @import.override? || contact.full_name.blank?
    contact.greeting = line['Greeting'] if @import.override? || contact.greeting.blank?
    contact.website = line['Web Page'] if @import.override? || contact.website.blank?
    contact.notes = line['Notes'] if @import.override? || contact.notes.blank?
    contact.pledge_amount = line['Pledge Amount'] if @import.override? || contact.pledge_amount.blank?
    contact.pledge_frequency = line['Pledge Frequency'] if (@import.override? || contact.pledge_frequency.blank?) && line['Pledge Frequency'].to_i != 0
    contact.pledge_start_date = parse_date(line['Pledge Start Date']) if (@import.override? || contact.pledge_start_date.blank?) && line['Pledge Start Date'].present?
    contact.status = lookup_mpd_phase(line['MPD Phase']) if (@import.override? || contact.status.blank?) && lookup_mpd_phase(line['MPD Phase']).present?
    contact.next_ask = parse_date(line['Next Ask']) if (@import.override? || contact.next_ask.blank?) && line['Next Ask'].present?
    contact.likely_to_give = contact.assignable_likely_to_gives[line['Likely To Give'].to_i - 1] if (@import.override? || contact.likely_to_give.blank?) && line['Likely To Give'].to_i != 0
    contact.never_ask = is_true?(line['Never Ask']) if @import.override? || contact.never_ask.blank?
    contact.church_name = line['Church Name'] if @import.override? || contact.church_name.blank?
    contact.send_newsletter = 'Physical' if (@import.override? || contact.send_newsletter.blank?) && is_true?(line['Send Newsletter'])
    contact.direct_deposit = is_true?(line['Direct Deposit']) if @import.override? || contact.direct_deposit.blank?
    contact.magazine = is_true?(line['Magazine']) if @import.override? || contact.magazine.blank?
    contact.last_activity = parse_date(line['Last Activity']) if (@import.override? || contact.last_activity.blank?) && line['Last Activity'].present?
    contact.last_appointment = parse_date(line['Last Appointment']) if (@import.override? || contact.last_appointment.blank?) && line['Last Appointment'].present?
    contact.last_letter = parse_date(line['Last Letter']) if (@import.override? || contact.last_letter.blank?) && line['Last Letter'].present?
    contact.last_phone_call = parse_date(line['Last Phone Call']) if (@import.override? || contact.last_phone_call.blank?) && line['Last Phone Call'].present?
    contact.last_pre_call = parse_date(line['Last Pre-Call']) if (@import.override? || contact.last_pre_call.blank?) && line['Last Pre-Call'].present?
    contact.last_thank = parse_date(line['Last Thank']) if (@import.override? || contact.last_thank.blank?) && line['Last Thank'].present?
    contact.tag_list.add(@import.tags, parse: true) if @import.tags.present?
    contact.addresses_attributes = build_address_array(line)
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
    when 30 then 'Call for Appointment'
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

  def add_or_update_company(account_list, user, line, donor_account)
    master_company = MasterCompany.find_by_name(line['Organization Name'])
    company = user.partner_companies.where(master_company_id: master_company.id).first if master_company

    company ||= account_list.companies.new({master_company: master_company}, without_protection: true)
    company.assign_attributes( {name: line['Organization Name'],
                                phone_number: line['Phone'],
                                street: line['Mailing Street Address'],
                                city: line['Mailing City'],
                                state: line['Mailing State'],
                                postal_code: line['Mailing Postal Code'],
                                country: line['Mailing Country']}, without_protection: true )
    company.save!
    donor_account.update_attribute(:master_company_id, company.master_company_id) unless donor_account.master_company_id == company.master_company.id
    company
  end


  def add_or_update_primary_contact(account_list, user, line, donor_account, contact)
    remote_id = "#{donor_account.account_number}-1"
    add_or_update_person(account_list, user, line, donor_account, remote_id, contact, '')
  end

  def add_or_update_spouse(account_list, user, line, donor_account, contact)
    remote_id = "#{donor_account.account_number}-2"
    add_or_update_person(account_list, user, line, donor_account, remote_id, contact, 'Spouse ')
  end

  def add_or_update_person(account_list, user, line, donor_account, remote_id, contact, prefix = '')
    line[prefix + 'First/Given Name'] = 'Unknown' if line[prefix + 'First/Given Name'].blank?
    organization = donor_account.organization
    # See if there's already a person by this name on this contact (This is a contact with multiple donation accounts)
    contact_person = contact.people.where(first_name: line[prefix + 'First/Given Name'], last_name: line[prefix + 'Last/Family Name'], middle_name: line[prefix + 'Middle Name']).first
    if contact_person
      person = Person.new({master_person: contact_person.master_person}, without_protection: true)
    else
      master_person_from_source = organization.master_people.where('master_person_sources.remote_id' => remote_id).first
      person = donor_account.people.where(master_person_id: master_person_from_source.id).first if master_person_from_source

      person ||= Person.new({master_person: master_person_from_source}, without_protection: true)
    end
    person.attributes = {first_name: line[prefix + 'First/Given Name'], last_name: line[prefix + 'Last/Family Name'], middle_name: line[prefix + 'Middle Name'],
                          title: line[prefix + 'Title'], suffix: line[prefix + 'Suffix'], gender: prefix.present? ? 'female' : 'male'}
    # Phone numbers
    {'Home Phone' => 'home', 'Home Phone 2' => 'home', 'Home Fax' => 'fax',
     'Business Phone' => 'work', 'Business Phone 2' => 'work', 'Business Fax' => 'fax',
     'Company Main Phone' => 'work', 'Assistant Phone' => 'work', 'Other Phone' => 'other',
     'Car Phone' => 'mobile', 'Mobile Phone' => 'mobile', 'Pager Number' => 'other',
     'Callback Phone' => 'other', 'ISDN Phone' => 'other', 'Primary Phone' => 'other',
     'Radio Phone' => 'other', 'Telex Phone' => 'other'}.each_with_index do |key, location, i|
       person.phone_number = {number: line[key], location: location, primary: line['Preferred Phone Type'].to_i == i} if line[key].present?
     end

    # email address
    3.times do |i|
      person.email_address = {email: line["Email #{i}"], primary: line['Preferred Email Types'] == i} if line["Email #{i}"].present?
    end

    # TODO: deal with other TNT fields

    person.master_person_id ||= MasterPerson.find_or_create_for_person(person, donor_account: donor_account, remote_id: remote_id).try(:id)
    person.save!

    donor_account.master_people << person.master_person unless donor_account.master_people.include?(person.master_person)

    contact_person ||= contact.add_person(person)

    # create the master_person_source if needed
    unless master_person_from_source
      organization.master_person_sources.where(remote_id: remote_id).first_or_create({master_person_id: person.master_person.id}, without_protection: true)
    end

    [person, contact_person]
  end

  def add_or_update_donor_accounts(line, account_list, designation_profile)
    contact = nil # create the contact variable outside the block scop
    if designation_profile
      donor_accounts = line['Organization Account IDs'].to_s.split(',').collect do |account_number|
        donor_account = designation_profile.organization.donor_accounts.where(account_number: account_number).first_or_create(name: line['File As'])
        donor_account.name = line['File As'] # if the acccount already existed, update the name

        donor_account.addresses_attributes = build_address_array(line)
        donor_account.save!
        contact = donor_account.link_to_contact_for(account_list)
        donor_account
      end
    end

    # If there was no donor account, we won't have a linked contact
    unless contact
      # try to find a contact with a person who has the same name already in the system
      contact ||= account_list.contacts.includes(:people).where('people.first_name' => line['First/Given Name'], 'people.last_name' => line['Last/Family Name']).first
      contact ||= account_list.contacts.includes(:people).where('people.first_name' => line['Spouse First/Given Name'], 'people.last_name' => line['Last/Family Name']).first
      contact ||= account_list.contacts.where(name: line['File As']).first_or_create
    end

    [donor_accounts, contact]
  end

  def build_address_array(line)
    addresses = []
    %w[Home Business Other].each_with_index do |location, i|
      if [line["#{location} Street Address"],line["#{location} City"],line["#{location} State/Province"],line["#{location} ZIP/Postal Code"]].any?(&:present?)
        addresses << {
                        street: line["#{location} Street Address"],
                        city: line["#{location} City"],
                        state: line["#{location} State/Province"],
                        postal_code: line["#{location} ZIP/Postal Code"],
                        country: line["#{location} Country/Region"],
                        location: location,
                        primary_mailing_address: line['Preferred Address Type'].to_i == (i + 1)
                      }
      end
    end

    addresses
  end

  def self.required_columns
    ['ContactID', 'Is Organization', 'Organization Account IDs']
  end

end
