class User < Person

  has_many :account_list_users
  has_many :account_lists, through: :account_list_users
  has_many :contacts, through: :account_lists
  has_many :contact_people, through: :contacts
  has_many :people, through: :contact_people
  has_many :account_list_entries, through: :account_lists
  has_many :designation_accounts, through: :account_list_entries
  has_many :designation_profiles
  has_many :partner_companies, through: :account_lists, source: :companies
  has_many :imports

  devise :trackable
  store :preferences, accessors: [:time_zone, :locale, :setup]

  attr_accessible :first_name, :last_name

  after_create :set_setup_mode

  # Queue data imports
  def queue_imports
    organization_accounts.map(&:queue_import_data)
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

  private
    def set_setup_mode
      if preferences[:setup].nil?
        self.preferences[:setup] = true
        save(validate: false)
      end
    end

end
