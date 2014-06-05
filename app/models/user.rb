class User < Person

  has_many :account_list_users, dependent: :destroy
  has_many :account_lists, through: :account_list_users
  has_many :contacts, through: :account_lists
  has_many :account_list_entries, through: :account_lists
  has_many :designation_accounts, through: :account_list_entries
  has_many :donations, through: :designation_accounts
  has_many :designation_profiles, dependent: :destroy
  has_many :partner_companies, through: :account_lists, source: :companies
  has_many :imports, dependent: :destroy

  devise :trackable
  store :preferences, accessors: [:time_zone, :locale, :setup, :contacts_filter,
                                  :tasks_filter, :default_account_list, :contacts_view_options,
                                  :tab_orders]

  accepts_nested_attributes_for :account_lists

  after_create :set_setup_mode

  # Queue data imports
  def queue_imports
    organization_accounts.each do |oa|
      oa.queue_import_data unless oa.last_download
      #oa.queue_import_data unless oa.downloading? || (oa.last_download && oa.last_download > 1.day.ago)
    end
  end

  def tab_order_by_location(location)
    orders = tab_orders || {}
    orders[location] || []
  end

  def merge(other)
    User.transaction do
      other.account_list_users.each do |other_alu|
        other_alu.update_column(:user_id, id) unless account_list_users.detect {|alu| alu.account_list_id == other_alu.account_list_id }
      end

      other.designation_profiles.each do |other_dp|
        other_dp.update_column(:user_id, id) unless designation_profiles.detect {|dp| dp.code == other_dp.code}
      end

      imports.update_all(user_id: id)
    end

    super
  end

  def setup_mode?
    setup == true || organization_accounts.blank?
  end

  def setup_finished!
    if setup_mode?
      self.setup = nil
      save(validate: false)
    end
  end

  def designation_numbers(organization_id)
    designation_accounts.where(organization_id: organization_id).pluck('designation_number')
  end

  def account_lists_attributes=(account_lists_array)
    account_lists_array = account_lists_array.values if account_lists_array.is_a?(Hash)
    account_lists_array.each do |account_list_attributes|
      account_list = account_lists.find(account_list_attributes['id'])
      account_list.update_attributes(account_list_attributes)
    end
  end

  def self.from_omniauth(provider, auth_hash)
    # look for an authenticated record from this provider
    user = provider.find_authenticated_user(auth_hash)
    unless user
      # TODO hook into IdM to find other identities for this person
      # that might link to an existing user in MPDX

      # Create a new user
      user = provider.create_user_from_auth(auth_hash)
    end
    user
  end

  def self.from_access_token(token)
    User.find_by_access_token(token) ||
    get_user_from_cas_oauth(token)
  end

  def self.get_user_from_cas_oauth(token)
    return nil unless token.present?

    begin
      response = RestClient.get("http://oauth.ccci.us/users/#{token}")
    rescue RestClient::Unauthorized
      return nil
    end

    json = JSON.parse(response.to_str)
    if account = Person::RelayAccount.find_by_remote_id(json['guid'])
      user = account.person.to_user
      user.update_attribute(:access_token, token)
      user
    else
      nil
    end
  end

  def to_person
    Person.find(self.id)
  end

  private
    def set_setup_mode
      if preferences[:setup].nil?
        self.preferences[:setup] = true
        save(validate: false)
      end
    end

end
