require 'google_contact_sync'
require 'google_contacts_cache'

class GoogleContactsIntegrator
  attr_accessor :assigned_remote_ids, :cache, :client

  CONTACTS_GROUP_TITLE = 'MPDX'

  # Caching the Google contacts from one big request speeds up the sync as we don't need separate HTTP get requests
  # But is only worth it if we are syncing a number of contacts, so check the number against this threshold.
  CACHE_ALL_G_CONTACTS_THRESHOLD = 10

  MAX_CONTACTS_TO_SYNC_CHECKS = 3

  def initialize(google_integration)
    @integration = google_integration
    @account = google_integration.google_account
  end

  def sync_contacts
    # This sync_contacts method is queued when a user in MPDX modifies a contact. The contacts_to_sync will query
    # the database for contacts that have been modified since they were last synced.
    #
    # However, it's possible that after editing on contact, the user will then edit another contact before the sync has
    # finished. In that case, sidekiq would attempt to queue the contact sync job, but it would not queue the job because
    # a sync for that integration (account list and google account basically) is already running (sidekiq_unique_jobs is the
    # gem that would prevent a second job from being queued). That's a good thing because the sync code is designed to
    # have only one instance of it running at a given time for a given integration.
    #
    # What we can do to solve this is check at the end of a sync to see if there are any more contacts that were modified
    # since the sync began, and then at the end of that sync again, etc. until we do a check for modified contacts and find
    # that none have been modified during the last sync in which case we can quit knowing the next modified contact
    # will queue the sync job again. (The query to check for modified contacts runs quickly so there is only a small
    # probability that someone could modify a contact during the query itself and anyway, that contact would just get
    # synced after the next contact was modified).
    #
    # Because due to unforseen circumstances, I could imagine that turning into a wasteful infinite loop, I cut off
    # the number of checks at a constant value of 10.
    contacts_to_sync_checks = 0
    until sync_and_return_num_synced == 0 || contacts_to_sync_checks >= MAX_CONTACTS_TO_SYNC_CHECKS
      contacts_to_sync_checks += 1
    end
  rescue Person::GoogleAccount::MissingRefreshToken
    # Don't log this exception as we expect it to happen from time to time.
    # Person::GoogleAccount will turn off the contacts integration and send the user an email to refresh their Google login.
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def sync_and_return_num_synced
    @cache = GoogleContactsCache.new(@account)
    contacts = contacts_to_sync
    return 0 if contacts.empty?

    setup_assigned_remote_ids
    @contacts_to_retry_sync = []

    # Each individual google_contact record also tracks a last synced time which will reflect when that particular person
    # was synced as well, this integration overall sync time is used though for querying the Google Contacts API for
    # updated google contacts, so setting the last synced time at the start of th sync would capture Google contacts
    # changed during the sync in the next sync.
    @integration.contacts_last_synced = Time.now

    contacts.each(&method(:sync_contact))
    api_user.send_batched_requests

    # For contacts syncs to the Google Contacts API that were either deleted or modified during the sync
    # and so caused a 404 Contact Not Found or a 412 Precondition Mismatch (i.e. ETag mismatch, i.e. contact changed),
    # we can attempt to retry them by re-executing the sync logic which will pull down the Google Contacts information
    # and re-compare with it. The save_g_contacts_then_links method below may populate @contacts_to_retry_sync.
    # Only retry the sync once though in case one of those problems was caused by something that would be ongoing
    # despite re-applying the sync logic.
    @contacts_to_retry_sync.each(&:reload)
    @contacts_to_retry_sync.each(&method(:sync_contact))
    api_user.send_batched_requests

    delete_g_contact_merge_losers

    @integration.save

    contacts.size
  end

  def delete_g_contact_merge_losers
    g_contact_merge_losers.each do |g_contact_link|
      api_user.delete_contact(g_contact_link.remote_id, g_contact_link.last_etag)
      g_contact_link.destroy
    end
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def g_contact_merge_losers
    # Return the google_contacts record for this Google account that are no longer associated with a contact-person pair
    # due to that contact or person being merged with another contact or person in MPDX.
    @account.google_contacts
      .joins('LEFT JOIN contact_people ON '\
        'google_contacts.person_id = contact_people.person_id AND contact_people.contact_id = google_contacts.contact_id')
      .where('contact_people.id IS NULL')
  end

  def api_user
    @account.contacts_api_user
  end

  def setup_assigned_remote_ids
    @assigned_remote_ids = @integration.account_list.contacts.joins(:people)
      .joins('INNER JOIN google_contacts ON google_contacts.person_id = people.id')
      .pluck('google_contacts.remote_id').to_set
  end

  def contacts_to_sync
    if @integration.contacts_last_synced
      updated_g_contacts = api_user.contacts_updated_min(@integration.contacts_last_synced)

      queried_contacts_to_sync = contacts_to_sync_query(updated_g_contacts.map(&:id))
      if queried_contacts_to_sync.length > CACHE_ALL_G_CONTACTS_THRESHOLD
        @cache.cache_all_g_contacts
      else
        @cache.cache_g_contacts(updated_g_contacts)
      end

      queried_contacts_to_sync
    else
      # Cache all contacts for the initial sync as all active MPDX contacts will need to be synced so most likely worth it.
      @cache.cache_all_g_contacts
      @integration.account_list.active_contacts
    end
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

  def sync_contact(contact)
    STDERR.puts "Sync contact: #{contact}"

    g_contacts_and_links = contact.contact_people.map(&method(:get_g_contact_and_link))
    GoogleContactSync.sync_contact(contact, g_contacts_and_links)
    contact.save(validate: false)

    g_contacts_to_save = g_contacts_and_links.select(&method(:g_contact_needs_save?)).map(&:first)
    if g_contacts_to_save.empty?
      save_g_contact_links(g_contacts_and_links)
    else
      save_g_contacts_then_links(contact, g_contacts_to_save, g_contacts_and_links)
    end
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def get_g_contact_and_link(contact_person)
    g_contact_link =
      @account.google_contacts.where(person: contact_person.person, contact: contact_person.contact).first_or_initialize
    g_contact = get_or_query_g_contact(g_contact_link, contact_person.person)

    if g_contact
      @assigned_remote_ids << g_contact.id
    else
      g_contact = GoogleContactsApi::Contact.new
      g_contact_link.last_data = {}
    end
    g_contact.prep_add_to_group(mpdx_group)

    STDERR.puts "get_g_contact_and_link for #{contact_person}: #{contact_person.contact}, #{contact_person.person}"
    STDERR.puts "g_contact remote id: #{g_contact.id}, g_contact_link id: #{g_contact_link.id}"

    [g_contact, g_contact_link]
  end

  def mpdx_group
    @mpdx_group ||= api_user.groups.find { |group| group.title == CONTACTS_GROUP_TITLE } ||
      GoogleContactsApi::Group.create({ title: CONTACTS_GROUP_TITLE }, api_user.api)
  end

  def get_or_query_g_contact(g_contact_link, person)
    return @cache.find_by_id(g_contact_link.remote_id) if g_contact_link.remote_id

    @cache.select_by_name(person.first_name, person.last_name).find do |g_contact|
      !@assigned_remote_ids.include?(g_contact.id)
    end
  end

  def g_contact_needs_save?(g_contact_and_link)
    g_contact, g_contact_link = g_contact_and_link
    g_contact.attrs_with_changes != g_contact_link.last_data
  end

  def save_g_contacts_then_links(contact, g_contacts_to_save, g_contacts_and_links)
    retry_sync = false

    g_contacts_to_save.each_with_index do |g_contact, index|
      g_contact_link = g_contacts_and_links.find { |g_contact_and_link| g_contact_and_link.first == g_contact }.second

      # The Google Contacts API batch requests significantly speed up the sync by reducing HTTP requests
      api_user.batch_create_or_update(g_contact) do |status|
        # This block is called for each saved g_contact once its batch completes
        begin
          # If any g_contact save failed but can be retried, then mark that we should queue the MPDX contact for a retry
          # sync once we get to the last associated g_cotnact
          retry_sync = true if failed_but_can_retry?(status, g_contact, g_contact_link)

          # When we get to last associated g_contact, then either save or queue for retry the MPDX contact
          next unless index == g_contacts_to_save.size - 1
          if retry_sync
            @contacts_to_retry_sync << contact
          else
            save_g_contact_links(g_contacts_and_links)
          end
        rescue => e
          # Rescue within this block so that the exception won't cause the response callbacks for the whole batch to break
          Airbrake.raise_or_notify(e)
        end
      end
    end
  end

  def failed_but_can_retry?(status, g_contact_saved, g_contact_link)
    case status[:code]
    when 200, 201
      # Didn't fail, so by the method semantics, return false
      return false
    when 404, 412
      # 404 is Not found, the google contact was deleted since the last sync
      # 412 is Precondition Failed (ETag mismatch), so the google contact was changed since the sync was started

      # Correct the cache to reflect that this contact has been modified or deleted and so shouldn't be cached
      @cache.remove_g_contact(g_contact_saved)

      if status[:code] == 404
        # If the contact was not found, delete the associated g_contact_link record, so we'll recreate a Google Contact
        # on retry
        g_contact_link.destroy
      else
        # If the Google Contact was modified during the sync operation, set the last synced time to nul to force
        # re-comparing with the updated Google contact
        g_contact_link.update(last_synced: nil)
      end

      return true
    else
      # Failed but can't just fix by resyncing the contact, so raise an error
      fail(status.inspect)
    end
  end

  def save_g_contact_links(g_contacts_and_links)
    g_contacts_and_links.each do|g_contact_and_link|
      g_contact, g_contact_link  = g_contact_and_link
      @assigned_remote_ids.add(g_contact.id)
      g_contact_link.update(last_data: g_contact.formatted_attrs, remote_id: g_contact.id, last_etag: g_contact.etag, last_synced: Time.now)
    end
  end
end
