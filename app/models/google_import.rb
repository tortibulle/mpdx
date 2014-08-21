class GoogleImport
  def initialize(import)
    @user = import.user
    @import = import
    @account_list = import.account_list
  end

  def import
    return false unless @import.source_account_id

    google_account = @user.google_accounts.find(@import.source_account_id)
    begin
      google_account.update_column(:downloading, true)
      import_contacts(google_account)
    ensure
      google_account.update_column(:downloading, false)
      google_account.update_column(:last_download, Time.now)
    end
  end

  def import_contacts(google_account)
    if @import.import_by_group
      @import.groups.each do |group_id|
        import_contacts_batch(google_account.contacts_for_group(group_id),
                              @import.tags + ',' + @import.group_tags[group_id])
      end
    else
      import_contacts_batch(google_account.contacts, @import.tags)
    end
  end

  def import_contacts_batch(google_contacts, tags)
    google_contacts.each do |g_contact|
      begin
        import_contact(g_contact, tags)
      rescue => e
        Airbrake.raise_or_notify(e)
        next
      end
    end
  end

  def import_contact(g_contact, tags)
    return unless g_contact.given_name

    person = create_or_update_person(g_contact)
    contact = create_or_update_contact(person, g_contact, tags)

    contact.people.reload

    begin
      contact.people << person unless contact.people.include?(person)
    rescue ActiveRecord::RecordNotUnique
    end
  end

  def create_or_update_contact(person, g_contact, tags)
    contact = @account_list.contacts.with_person(person).first

    unless contact
      name = "#{person.last_name}, #{person.first_name}"
      contact = @account_list.contacts.find_or_create_by(name: name)
    end

    contact.addresses_attributes = g_contact.addresses.map { |address| build_address(address, contact) }
    contact.tag_list.add(tags, parse: true) if tags.present?
    contact.save
    contact
  end

  def build_address(google_address, contact)
    address = {
      street:  google_address[:street], city: google_address[:city], state: google_address[:region],
      postal_code: google_address[:postcode],
      country: google_address[:country] == 'United States of America' ? 'United States' : google_address[:country],
      location: google_address_rel_to_location(google_address[:rel])
    }

    if google_address[:primary] && (@import.override || contact.addresses.count == 0)
      contact.addresses.each { |non_primary| non_primary.update_attribute(:primary_mailing_address, false) }
      address[:primary_mailing_address] = true
    end

    address
  end

  def google_address_rel_to_location(rel)
    if rel == 'work'
      'Business'
    elsif rel == 'home'
      'Home'
    else
      'Other'
    end
  end

  def create_or_update_person(g_contact)
    person = create_or_update_person_basic_info(g_contact)

    unless person.google_contacts.pluck(:remote_id).include?(g_contact.id)
      person.google_contacts.create!(remote_id: g_contact.id)
    end

    update_person_emails(person, g_contact)
    update_person_phones(person, g_contact)

    person.save
    person
  end

  def create_or_update_person_basic_info(g_contact)
    person = (@account_list.people.includes(:google_contacts).where('google_contacts.remote_id' => g_contact.id).first ||
              @account_list.people.where(first_name: g_contact.given_name, last_name: g_contact.family_name).first)

    person_attributes = {
      title: g_contact.name_prefix, first_name: g_contact.given_name, middle_name: g_contact.additional_name,
      last_name: g_contact.family_name,  suffix: g_contact.name_suffix
    }.select { |_, v| v.present? }

    if person
      person.update_attributes(person_attributes)
      person
    else
      Person.create!(person_attributes)
    end
  end

  def update_person_emails(person, g_contact)
    num_emails_before_import = person.email_addresses.count
    g_contact.emails_full.each do |import_email|
      email = { email: import_email[:address], location: import_email[:rel] }
      if import_email[:primary] && (@import.override || num_emails_before_import == 0)
        person.email_addresses.update_all primary: false
        email[:primary] = true
      end
      person.email_address = email
    end
  end

  def update_person_phones(person, g_contact)
    num_phones_before_import = person.phone_numbers.count
    g_contact.phone_numbers_full.each do |import_phone|
      phone = { number: import_phone[:number], location: import_phone[:rel] }
      if import_phone[:primary] && (@import.override || num_phones_before_import == 0)
        person.phone_numbers.update_all primary: false
        phone[:primary] = true
      end
      person.phone_number = phone
    end
  end
end
