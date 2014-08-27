class GoogleContactsIntegrator
  attr_accessor :client

  def initialize(google_integration)
    @google_integration = google_integration
    @google_account = google_integration.google_account
    @client = @google_account.client
  end

  def sync_contacts
    @google_integration.account_list.active_contacts.each { |contact| sync_contact(contact) }
  end

  def sync_contact(contact)
    contact.people.each { |person| sync_person(person, contact) }
  end

  def sync_person(person, contact)
    unless person.google_contacts.find(source_google_account: @google_account)
      create_google_contact_for_person(person, contact)
    end
  end

  def create_google_contact_for_person(person, contact)
    g_contact_attrs = {
      name_prefix: person.title,
      given_name: person.first_name,
      additional_name: person.middle_name,
      family_name: person.last_name,
      name_suffix: person.suffix,
      emails: person.email_addresses.map(&method(:format_email_for_google)),
      phone_numbers: person.phone_numbers.map(&method(:format_phone_for_google)),
      addresses: contact.addresses.map(&method(:format_address_for_google))
    }

    # post to this URL:
    # https://www.google.com/m8/feeds/contacts/{userEmail}/full
    remote_id = @google_account.contacts_api_user.create_contact(g_contact_attrs)
    if remote_id
      person.google_contacts.create(remote_id: remote_id, source_google_account_id: @google_account.id)
    end
  end

  def format_email_for_google(email)
    { address: email.email, primary: email.primary, rel: email.location.in?(['work', 'home']) ? email.location : 'other' }
  end

  def format_phone_for_google(phone)
    # From https://developers.google.com/gdata/docs/2.0/elements#gdPhoneNumber
    allowed_rels = %w(assistant callback car company_main fax home home_fax isdn main mobile other other_fax pager radio telex tty_tdd work work_fax work_mobile work_pager)
    { number: phone.number, primary: phone.primary, rel: phone.location.in?(allowed_rels) ? phone.location : 'other' }
  end

  def format_address_for_google(address)
    { rel: address_location_to_rel(address.location), primary: address.primary,
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
