class Organization < ActiveRecord::Base
  has_many :designation_accounts, dependent: :destroy
  has_many :designation_profiles, dependent: :destroy
  has_many :donor_accounts, dependent: :destroy
  has_many :master_person_sources, dependent: :destroy
  has_many :master_people, through: :master_person_sources

  validates :name, :query_ini_url, presence: true
  scope :active, -> { where('addresses_url is not null') }

  # attr_accessible :name, :query_ini_url, :iso3166, :redirect_query_ini, :abbreviation, :logo, :account_help_url,
  #                 :minimum_gift_date, :code, :query_authentication, :org_help_email, :org_help_url,
  #                 :org_help_url_description, :org_help_other, :request_profile_url, :staff_portal_url,
  #                 :default_currency_code, :allow_passive_auth, :account_balance_params, :account_balance_url,
  #                 :donations_params, :donations_url, :addresses_params, :addresses_url, :addresses_by_personids_params,
  #                 :addresses_by_personids_url, :profiles_url, :profiles_params

  def to_s() name; end

  def api(org_account)
    api_class.constantize.new(org_account)
  end

  def requires_username_and_password?
    api_class.constantize.requires_username_and_password?
  end

  def self.cru_usa
    Organization.find_by_code('CCC-USA')
  end
end
