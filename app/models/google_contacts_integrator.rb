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
    contact.people.each do |person|
      begin
        sync_person(person, contact)
      rescue => e
        Airbrake.raise_or_notify(e)
        next
      end
    end
  end

  def sync_person(person, contact)
    g_contact_link = person.google_contacts.first_or_initialize(google_account: @account)
    g_contact = get_or_query_g_contact(g_contact_link, person)

    if g_contact.nil?
      g_contact = create_g_contact(person, contact)
    else
      sync_with_g_contact(person, contact, g_contact, g_contact_link)
    end

    g_contact_link.last_data = g_contact.formatted_attrs
    g_contact_link.last_mappings = mpdx_to_g_contact_mappings(person, contact)
    g_contact_link.remote_id = g_contact.id
    g_contact_link.last_etag = g_contact.etag
    g_contact_link.last_synced = Time.now
    g_contact_link.save
  end

  def mpdx_to_g_contact_mappings(person, _contact)
    { emails: Hash[person.email_addresses.map { |e| [e.id, e.email] }] }
  end

  def get_or_query_g_contact(g_contact_link, person)
    g_contact_link.remote_id ? get_g_contact(g_contact_link.remote_id) : query_g_contact(person)
  end

  def get_g_contact(remote_id)
    @account.contacts_api_user.get_contact(remote_id)
  end

  def query_g_contact(person)
    @account.contacts_api_user.query_contacts(person.first_name + ' ' + person.last_name).find do |g_contact|
      g_contact.given_name == person.first_name && g_contact.family_name == person.last_name
    end
  end

  def create_g_contact(person, contact)
    @account.contacts_api_user.create_contact(
      name_prefix: person.title,
      given_name: person.first_name,
      additional_name: person.middle_name,
      family_name: person.last_name,
      name_suffix: person.suffix,
      content: contact.notes,
      emails: person.email_addresses.map(&method(:format_email_for_google)),
      phone_numbers: person.phone_numbers.map(&method(:format_phone_for_google)),
      organizations: g_contact_organizations_for(person),
      websites: person.websites.map(&method(:format_website_for_google)),
      addresses: contact.addresses.map(&method(:format_address_for_google))
    )
  end

  ################################################################################
  ## Sync of basic fields
  ################################################################################

  def sync_with_g_contact(person, contact, g_contact, g_contact_link)
    sync_basic_person_fields(g_contact, person)
    sync_contact_fields(g_contact, contact)
    sync_employer_and_title(g_contact, person)
    sync_emails(g_contact, person, g_contact_link)

    g_contact.send_update
    person.save
    contact.save
  end

  def sync_contact_fields(g_contact, contact)
    sync_g_contact_and_record(g_contact, contact, notes: :content)
  end

  def sync_basic_person_fields(g_contact, person)
    sync_g_contact_and_record(g_contact, person, title: :name_prefix, first_name: :given_name,
                              middle_name: :additional_name, last_name: :family_name,
                              suffix: :name_suffix)
  end

  def sync_g_contact_and_record(g_contact, record, field_map)
    field_map.each do |field, g_contact_field|
      if record[field].present?
        g_contact.prep_update(g_contact_field => record[field]) unless g_contact.send(g_contact_field).present?
      else
        record[field] = g_contact.send(g_contact_field)
      end
    end
  end

  def sync_employer_and_title(g_contact, person)
    person_orgs = g_contact_organizations_for(person)
    g_contact_orgs = g_contact.organizations
    if person_orgs.empty?
      first_org = g_contact_orgs.first
      person.update(employer: first_org[:org_name], occupation: first_org[:org_title]) if first_org
    else
      g_contact.prep_update(organizations: person_orgs) if g_contact_orgs.empty?
    end
  end

  ################################################################################
  ## Email two-way sync
  ################################################################################

  # Propages adds and deletes between both the Google Contact and MPDX. An update just becomes an add and a delete
  def sync_emails(g_contact, person, g_contact_link)
    g_contact_adds, g_contact_dels, mpdx_adds, mpdx_dels = compare_emails_for_sync(g_contact, person, g_contact_link)

    g_contact_emails = g_contact.emails_full

    (g_contact_adds - mpdx_adds).each do |add_in_mpdx|
      person.email_address = format_email_for_mpdx(find_hash(g_contact_emails, address: add_in_mpdx))
    end
    (g_contact_dels - mpdx_dels).each { |delete_in_mpdx| person.email_addresses.delete(email: delete_in_mpdx) }

    g_contact_emails += (mpdx_adds - g_contact_adds).map do |add_in_g_contact|
      format_email_for_google(person.email_addresses.find_by_email(add_in_g_contact))
    end
    g_contact_emails.delete_if { |e| mpdx_dels.include?(e[:address]) }
    g_contact.prep_update(emails: g_contact_emails)
  end

  def compare_emails_for_sync(g_contact, person, g_contact_link)
    g_contact_emails_full = g_contact.emails_full
    last_emails = g_contact_link.new_record? ? Set.new : g_contact_link.last_data[:emails].map { |e| e[:address] }.to_set
    mpdx_emails = person.email_addresses.map(&:email).to_set
    g_contact_emails = g_contact_emails_full.map { |e| e[:address] }.to_set

    g_contact_adds = (g_contact_emails - last_emails)
    g_contact_dels = (last_emails - g_contact_emails)
    mpdx_adds = (mpdx_emails - last_emails)
    mpdx_dels = (last_emails - mpdx_emails)

    [g_contact_adds, g_contact_dels, mpdx_adds, mpdx_dels]
  end

  def find_hash(hashes_list, search_key_value)
    key = search_key_value.keys[0]
    value = search_key_value.values[0]
    hashes_list.find { |hash| hash[key] == value }
  end

  ################################################################################
  ## Helper functions
  ################################################################################

  def g_contact_organizations_for(person)
    if person.employer.present? || person.occupation.present?
      [{ org_name: person.employer, org_title: person.occupation, primary: true }]
    else
      []
    end
  end

  def format_email_for_mpdx(email)
    { email: email[:address], primary: email[:primary], location: email[:rel] }
  end

  def format_email_for_google(email)
    { primary: email.primary, rel: email.location.in?(%w(work home)) ? email.location : 'other', address: email.email }
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
