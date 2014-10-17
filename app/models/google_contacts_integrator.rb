require 'google_contact_sync'

class GoogleContactsIntegrator
  attr_accessor :client
  attr_accessor :assigned_remote_ids

  # All of the created/updated Google Contacts will be assigned to this group (and the group created if needed)/
  CONTACTS_GROUP_TITLE = 'MPDx'

  # Batching the API creates/updates significantly speeds up the sync by reducing the number of API HTTP requests.
  # Google Contacts API limits it to 100.
  BATCH_SIZE = 100

  # Seconds of delay between retries of 500 errors from Google Contacts API
  RETRY_DELAY = 30

  # Caching the Google contacts from one big request speeds up the sync as we don't need separate HTTP get requests
  # But is only worth it if we are syncing a number of contacts, so check the number against this threshold.
  CACHE_ALL_CONTACTS_THRESHOLD = 10

  def initialize(google_integration)
    @integration = google_integration
    @account = google_integration.google_account
    clear_save_batch
    clear_g_contact_cache
  end

  def sync_contacts
    @contacts_to_retry_sync = []
    contacts_to_sync.each(&method(:sync_contact))
    save_batched_syncs

    @contacts_to_retry_sync.each(&:reload)
    @contacts_to_retry_sync.each(&method(:sync_contact))
    save_batched_syncs

    clear_g_contact_cache

    @integration.contacts_last_synced = Time.now
    @integration.save
  rescue Person::GoogleAccount::MissingRefreshToken
    # Don't log this exception as we expect it to happen from time to time.
    # Person::GoogleAccount will turn off the contacts integration and send the user an email to refresh their Google login.
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def contacts_to_sync
    setup_assigned_remote_ids

    if @integration.contacts_last_synced
      updated_g_contacts = contacts_api_user.contacts_updated_min(@integration.contacts_last_synced)

      queried_contacts_to_sync = contacts_to_sync_query(updated_g_contacts.map(&:id))
      if queried_contacts_to_sync.length > CACHE_ALL_CONTACTS_THRESHOLD
        cache_g_contacts(contacts_api_user.contacts, true)
      else
        cache_g_contacts(updated_g_contacts, false)
      end

      queried_contacts_to_sync
    else
      # Cache all contacts for the initial sync as all active MPDX contacts will need to be synced so most likely worth it.
      cache_g_contacts(contacts_api_user.contacts, true)
      @integration.account_list.active_contacts
    end
  end

  def setup_assigned_remote_ids
    @assigned_remote_ids = @integration.account_list.contacts.joins(:people)
      .joins('INNER JOIN google_contacts ON google_contacts.person_id = people.id')
      .pluck('google_contacts.remote_id').to_set
  end

  # Queries all contacts that:
  # - Have some associted records updated_at more recent than its google_contact.contacts_last_synced
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

  def quote_sql_list(list)
    list.map { |item| ActiveRecord::Base.connection.quote(item) }.join(',')
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

  def remove_g_contact_from_cache(g_contact)
    @g_contact_by_id.delete(g_contact.id)
    @g_contacts_by_name["#{g_contact.given_name} #{g_contact.family_name}"].delete(g_contact)
    @all_g_contacts_cached = false
  end

  def clear_g_contact_cache
    @g_contact_by_id = {}
    @g_contacts_by_name = {}
    @all_g_contacts_cached = false
  end

  def sync_contact(contact)
    g_contacts_and_links = contact.people.map(&method(:get_g_contact_and_link))

    save_batched_syncs if g_contacts_and_links.size + @g_contacts_in_batch > BATCH_SIZE

    GoogleContactSync.sync_contact(contact, g_contacts_and_links)
    batch_save(contact, g_contacts_and_links)
  end

  def get_g_contact_and_link(person)
    g_contact_link = find_or_build_g_contact_link(person)
    g_contact = get_or_query_g_contact(g_contact_link, person)

    if g_contact
      @assigned_remote_ids << g_contact.id
    else
      g_contact = GoogleContactsApi::Contact.new(nil, nil, nil)
    end
    g_contact.prep_add_to_group(mpdx_group)

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

  def query_g_contact(person)
    lookup_g_contacts_for_name("#{person.first_name} #{person.last_name}").find do |g_contact|
      g_contact.given_name == person.first_name && g_contact.family_name == person.last_name &&
        !@assigned_remote_ids.include?(g_contact.id)
    end
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

  def mpdx_group
    @mpdx_group ||= find_or_create_mpdx_group
  end

  def find_or_create_mpdx_group
    mpdx_group = contacts_api_user.groups.find { |group| group.title == CONTACTS_GROUP_TITLE }
    return mpdx_group if mpdx_group

    GoogleContactsApi::Group.create({ title: CONTACTS_GROUP_TITLE }, contacts_api_user.api)
  end

  def contacts_api_user
    api_user = @account.contacts_api_user
    fail Person::GoogleAccount::MissingRefreshToken unless api_user
    api_user
  end

  def batch_save(contact, g_contacts_and_links)
    g_contacts_to_save = g_contacts_and_links.select(&method(:g_contact_needs_save)).map(&:first)

    if g_contacts_to_save.size > 0
      @batched_saves << [g_contacts_to_save, contact, g_contacts_and_links]
      @g_contacts_in_batch += g_contacts_to_save.size
    else
      save_records(contact, g_contacts_and_links)
    end
  end

  def g_contact_needs_save(g_contact_and_link)
    g_contact, g_contact_link = g_contact_and_link
    g_contact.attrs_with_changes != g_contact_link.last_data
  end

  def save_batched_syncs(num_retries = 1)
    return if @batched_saves.empty?

    batched_g_contacts_to_save = @batched_saves.flat_map(&:first)
    statuses = contacts_api_user.batch_create_or_update(batched_g_contacts_to_save)

    @batched_saves.each do |batched_save|
      g_contacts_saved, contact, g_contacts_and_links = batched_save
      statuses_for_batched_save = statuses.shift(g_contacts_saved.size)
      finish_batched_save(statuses_for_batched_save, contact, g_contacts_and_links)
    end

    clear_save_batch
  rescue OAuth2::Error => e
    if e.response.status >= 500 && num_retries > 0
      # Google Contacts API somtimes returns temporary errors that are worth giving another try to a bit later.
      sleep(RETRY_DELAY)
      save_batched_syncs(num_retries - 1)
    else
      raise e
    end
  end

  def finish_batched_save(statuses, contact, g_contacts_and_links)
    statuses.each do |status|
      case status[:code]
      when 200..201
        # Do nothing on success or created, just go ahead and save the records (below) if all succeeded.
      when 404, 412
        # 404 Not found, the google contact was deleted since the last sync
        # 412 ETag mismatch, the google contact was changed since the sync was started
        # In both cases, just remove all the google contacts from the cache and queue them for a retry
        # Return immediately and don't save the records
        g_contacts_and_links.map(&:first).each(&method(:remove_g_contact_from_cache))
        @contacts_to_retry_sync << contact
        return
      else
        fail(status.inspect)
      end
    end
    save_records(contact, g_contacts_and_links)
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def save_records(contact, g_contacts_and_links)
    contact.save!
    g_contacts_and_links.each { |g_contact_and_link| save_g_contact_link(*g_contact_and_link) }
  end

  def save_g_contact_link(g_contact, g_contact_link)
    @assigned_remote_ids.add(g_contact.id)
    g_contact_link.last_data = g_contact.formatted_attrs
    g_contact_link.remote_id = g_contact.id
    g_contact_link.last_etag = g_contact.etag
    g_contact_link.last_synced = Time.now
    g_contact_link.save
  end

  def clear_save_batch
    @batched_saves = []
    @g_contacts_in_batch = 0
  end
end
