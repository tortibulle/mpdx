class GoogleContactsCache
  def initialize(google_account)
    @account = google_account
  end

  def cache_all_g_contacts
    cache_g_contacts(@account.contacts_api_user.contacts, true)
  end

  def cache_g_contacts(g_contacts, all_cached = false)
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

  def find_by_id(remote_id)
    cached_g_contact = @g_contact_by_id[remote_id]
    return cached_g_contact if cached_g_contact
    return nil if @all_g_contacts_cached
    @account.contacts_api_user.get_contact(remote_id)
  rescue OAuth2::Error => e
    # Just return nil for a 404 Contact Not Found error, otherwise raise the error
    raise e unless e.response.status == 404
  end

  def select_by_name(first_name, last_name)
    query_by_full_name("#{first_name} #{last_name}").select do |g_contact|
      g_contact.given_name == first_name && g_contact.family_name == last_name
    end
  end

  def query_by_full_name(name)
    cached_g_contacts = @g_contacts_by_name[name]
    if cached_g_contacts
      cached_g_contacts
    elsif @all_g_contacts_cached
      []
    else
      @account.contacts_api_user.query_contacts(name)
    end
  end

  def remove_g_contact(g_contact)
    @g_contact_by_id.delete(g_contact.id)
    @g_contacts_by_name["#{g_contact.given_name} #{g_contact.family_name}"].delete(g_contact)
    @all_g_contacts_cached = false
  end
end
