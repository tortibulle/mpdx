require 'google_contact_sync'

class GoogleContactsIntegrator
  attr_accessor :client
  attr_accessor :assigned_remote_ids

  RETRY_DELAY = 30
  CONTACTS_GROUP_TITLE = 'MPDx'

  def initialize(google_integration)
    @integration = google_integration
    @account = google_integration.google_account
    clear_g_contact_cache
  end

  def sync_contacts
    contacts_to_sync.each(&method(:sync_contact))
    @integration.last_synced = Time.now
    @integration.save
    clear_g_contact_cache
  rescue Person::GoogleAccount::MissingRefreshToken
    # Don't log this exception as we expect it to happen from time to time.
    # Person::GoogleAccount will turn off the contacts integration and send the user an email to refresh their Google login.
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def mpdx_group
    @mpdx_group ||= find_or_create_mpdx_group
  end

  def find_or_create_mpdx_group
    mpdx_group = contacts_api_user.groups.find { |group| group.title == CONTACTS_GROUP_TITLE }
    return mpdx_group if mpdx_group

    GoogleContactsApi::Group.create({ title: CONTACTS_GROUP_TITLE }, contacts_api_user.api)
  end

  def contacts_to_sync
    setup_assigned_remote_ids

    if @integration.last_synced
      updated_g_contacts = contacts_api_user.contacts_updated_min(@integration.last_synced)

      cache_g_contacts(updated_g_contacts, false)

      contacts_to_sync_query(updated_g_contacts.map(&:id))
    else
      # For the first sync, we can down on HTTP requests by caching the list of Google Contacts
      cache_g_contacts(contacts_api_user.contacts, true)

      @integration.account_list.active_contacts
    end
  end

  def contacts_api_user
    api_user = @account.contacts_api_user
    fail Person::GoogleAccount::MissingRefreshToken unless api_user
    api_user
  end

  def setup_assigned_remote_ids
    @assigned_remote_ids = @integration.account_list.contacts.joins(:people)
      .joins('INNER JOIN google_contacts ON google_contacts.person_id = people.id')
      .pluck('google_contacts.remote_id').to_set
  end

  def quote_sql_list(list)
    list.map { |item| ActiveRecord::Base.connection.quote(item) }.join(',')
  end

  # Queries all contacts that:
  # - Have some associted records updated_at more recent than its google_contact.last_synced
  # - Or contacts without associated google_contacts records (i.e. which haven't been synced before)
  # - Or contacts whose google_contacts records have been updated remotely
  #   as specified by the updated_remote_ids
  def contacts_to_sync_query(updated_remote_ids)
    @integration.account_list.active_contacts
      .joins(:people)
      .joins("LEFT JOIN addresses ON addresses.addressable_id = contacts.id AND addresses.addressable_type = 'Contact'")
      .joins('LEFT JOIN email_addresses ON people.id = email_addresses.person_id')
      .joins('LEFT JOIN phone_numbers ON people.id = phone_numbers.person_id')
      .joins('LEFT JOIN person_websites ON people.id = person_websites.person_id')
      .joins('LEFT JOIN google_contacts ON google_contacts.person_id = people.id')
      .where('google_contacts.id IS NULL OR google_contacts.google_account_id = ?', @account.id)
      .group('contacts.id, google_contacts.last_synced, google_contacts.remote_id')
      .having('google_contacts.last_synced IS NULL ' \
        'OR google_contacts.last_synced < ' \
          'GREATEST(contacts.updated_at, MAX(contact_people.updated_at), MAX(people.updated_at), ' \
                  'MAX(addresses.updated_at), MAX(email_addresses.updated_at), '\
                  'MAX(phone_numbers.updated_at), MAX(person_websites.updated_at))' +
          (updated_remote_ids.empty? ? '' : " OR google_contacts.remote_id IN (#{ quote_sql_list(updated_remote_ids) })"))
      .distinct
      .readonly(false)
  end

  def clear_g_contact_cache
    @g_contact_by_id = {}
    @g_contacts_by_name = {}
    @all_g_contacts_cached = false
  end

  def cache_g_contacts(g_contacts, all_cached)
    @all_g_contacts_cached = all_cached

    @g_contact_by_id = Hash[g_contacts.map { |g_contact| [g_contact.id, g_contact] }]

    @g_contacts_by_name = {}
    g_contacts.each do |g_contact|
      name = "#{g_contact.given_name} #{g_contact.family_name}"
      name_list = @g_contacts_by_name[name]
      if name_list
        name_list << g_contact
      else
        @g_contacts_by_name[name] = [g_contact]
      end
    end
  end

  def sync_contact(contact)
    g_contacts_and_links = contact.people.map(&method(:sync_person))

    g_contacts = g_contacts_and_links.map(&:first)
    g_contact_links = g_contacts_and_links.map(&:second)
    GoogleContactSync.sync_addresses(g_contacts, contact, g_contact_links)

    g_contacts_and_links.each do |g_contact_and_link|
      g_contact, g_contact_link = g_contact_and_link
      GoogleContactSync.sync_notes(contact, g_contact, g_contact_link)

      g_contact.prep_add_to_group(mpdx_group)

      create_or_update_g_contact(g_contact, g_contact_link)
      store_g_contact_link(g_contact_link, g_contact)
    end

    contact.save
  end

  def create_or_update_g_contact(g_contact, g_contact_link, num_retries = 1)
    return if g_contact.attrs_with_changes == g_contact_link.last_data

    # Set the api for the g_contact again so that the token will be refreshed if needed
    g_contact.api = contacts_api_user.api

    g_contact.create_or_update
    @assigned_remote_ids << g_contact.id
  rescue OAuth2::Error => e
    if e.response.status >= 500 && num_retries > 0
      # Google Contacts API somtimes returns temporary errors that are worth giving another try to a bit later.
      sleep(RETRY_DELAY)
      create_or_update_g_contact(g_contact, g_contact_link, num_retries - 1)
    else
      raise e
    end
  end

  def store_g_contact_link(g_contact_link, g_contact)
    g_contact_link.last_data = g_contact.formatted_attrs
    g_contact_link.remote_id = g_contact.id
    g_contact_link.last_etag = g_contact.etag
    g_contact_link.last_synced = Time.now
    g_contact_link.save
  end

  def sync_person(person)
    g_contact_link = find_or_build_g_contact_link(person)
    g_contact = get_or_query_g_contact(g_contact_link, person)

    if g_contact
      @assigned_remote_ids << g_contact.id
    else
      g_contact = GoogleContactsApi::Contact.new(nil, nil, nil)
    end

    GoogleContactSync.sync_with_g_contact(person, g_contact, g_contact_link)

    [g_contact, g_contact_link]
  end

  def find_or_build_g_contact_link(person)
    person.google_contacts.where(google_account: @account)
      .first_or_initialize(person: person, last_data: { emails: [], addresses: [], phone_numbers: [], websites: [] })
  end

  def get_or_query_g_contact(g_contact_link, person)
    g_contact_link.remote_id ? get_g_contact(g_contact_link.remote_id) : query_g_contact(person)
  end

  def get_g_contact(remote_id)
    cached_g_contact = @g_contact_by_id[remote_id]
    cached_g_contact ? cached_g_contact : contacts_api_user.get_contact(remote_id)
  end

  def lookup_g_contacts_for_name(name)
    cached_g_contacts = @g_contacts_by_name[name]
    if cached_g_contacts
      cached_g_contacts
    elsif @all_g_contacts_cached
      []
    else
      contacts_api_user.query_contacts(name)
    end
  end

  def query_g_contact(person)
    lookup_g_contacts_for_name("#{person.first_name} #{person.last_name}").find do |g_contact|
      g_contact.given_name == person.first_name && g_contact.family_name == person.last_name &&
        !@assigned_remote_ids.include?(g_contact.id)
    end
  end
end
