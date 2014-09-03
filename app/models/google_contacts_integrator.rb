class GoogleContactsIntegrator
  attr_accessor :client

  def initialize(google_integration)
    @google_integration = google_integration
    @account = google_integration.google_account
  end

  def sync_contacts
    @google_integration.account_list.active_contacts.each { |contact| sync_contact(contact) }
  end

  def sync_contact(contact)
    contact.people.each { |person| sync_person(person, contact) }
  end

  def sync_person(person, contact)
    g_contact_record = person.google_contacts.find_by_google_account_id(@account.id)
    if g_contact_record
      g_contact = @account.contacts_api_user.get_contact(g_contact_record.remote_id)
    else
      g_contact = query_g_contact(person, contact)
    end

    if g_contact.nil?
      g_contact = create_g_contact(person, contact)
    else
      sync_with_g_contact(person, contact, g_contact_record, g_contact)
    end

    g_contact_record ||= person.google_contacts.build(remote_id: g_contact.id, google_account: @account)
    g_contact_record.last_etag = g_contact.etag
    g_contact_record.last_synced = Time.now
    g_contact_record.save
  end

  def query_g_contact(person, contact)
    @account.contacts_api_user.query_contacts(person.first_name + ' ' + person.last_name).find do |g_contact|
      g_contact.given_name == person.first_name && g_contact.family_name == person.last_name
    end
  end

  def sync_with_g_contact(person, contact, g_contact_record, g_contact, override = true, import_from_google = true)
    # We are already in sync with this contact
    return if g_contact_record && g_contact_record.last_etag == g_contact.etag

    g_contact_changes = {}

    person_to_g_contact_fields = {
      title: :name_prefix,
      first_name: :given_name,
      middle_name: :additional_name,
      last_name: :family_name,
      suffix: :name_suffix
    }
    person_to_g_contact_fields.each do |person_field, g_contact_field|
      if g_contact.send(g_contact_field).present?
        if person[person_field].present?
          g_contact_changes[g_contact_field] = person[person_field] if override
        else
          person.update(person_field => g_contact.send(g_contact_field)) if import_from_google
        end
      else
        g_contact_changes[g_contact_field] = person[person_field] if person[person_field].present?
      end
    end

    if g_contact.content.present?
      if contact.notes.present?
        g_contact_changes[:content] = contact.notes if override
      else
        contact.notes = g_contact.content if import_from_google
      end
    else
      g_contact_changes[:content] = contact.notes if contact.notes.present?
    end

    # TODO: Figure out employer and occupation

    # For array lists, like phone numbers, emails, addresses, websites:
    # If already associated with the contact && override => Favor MPDX completely

    person.save
    contact.save
  end

  def create_g_contact(person, contact)
    # TODO: Add in employer and occupation
    @account.contacts_api_user.create_contact(
      name_prefix: person.title,
      given_name: person.first_name,
      additional_name: person.middle_name,
      family_name: person.last_name,
      name_suffix: person.suffix,
      content: contact.notes,
      emails: person.email_addresses.map(&method(:format_email_for_google)),
      phone_numbers: person.phone_numbers.map(&method(:format_phone_for_google)),
      websites: person.websites.map(&method(:format_website_for_google)),
      addresses: contact.addresses.map(&method(:format_address_for_google))
    )
  end

  def format_email_for_google(email)
    { address: email.email, primary: email.primary, rel: email.location.in?(%w(work home)) ? email.location : 'other' }
  end

  def format_phone_for_google(phone)
    # From https://developers.google.com/gdata/docs/2.0/elements#gdPhoneNumber
    allowed_rels = %w(assistant callback car company_main fax home home_fax isdn main mobile other other_fax pager radio telex tty_tdd work work_fax work_mobile work_pager)
    { number: phone.number, primary: phone.primary, rel: phone.location.in?(allowed_rels) ? phone.location : 'other' }
  end

  def format_website_for_google(website)
    { href: website.url, primary: website.primary, rel: 'other' }
  end

  def format_address_for_google(address)
    { rel: address_location_to_rel(address.location), primary: address.primary_mailing_address,
      street: address.street, city: address.city, region: address.state, postcode: address.postal_code,
      country: address.country == 'United States' ? 'United States of America' : address.country }
  end

  def address_location_to_rel(location)
    if location == 'Business'
      'work'
    elsif location == 'Home'
      'home'
    else
      'other'
    end
  end
end
