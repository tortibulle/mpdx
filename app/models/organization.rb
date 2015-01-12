class Organization < ActiveRecord::Base
  include Async # To allow batch processing of address merges
  include Sidekiq::Worker
  sidekiq_options retry: false, unique: true, queue: :import # use low priority import queue

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

  # We had an organization, DiscipleMakers with a lot of duplicate addresses in its contacts and donor
  # accounts due to a difference in how their data server donor import worked and a previous iteration of
  # MPDX accepting duplicate addresses there. This will merge dup addresses in their donor accounts and
  # contacts. The merging takes a while given the large number of duplicate addressees, so it made
  # sense to run it as a single background job for the organizaton via Sidekiq/Async.
  def merge_all_dup_addresses
    # Use find_each with a small batch size to not use up memory
    donor_accounts.find_each(batch_size: 5) { |donor_account| donor_account.merge_addresses }

    account_lists = AccountList.joins(:users)
                      .joins('INNER JOIN person_organization_accounts ON person_organization_accounts.person_id = people.id')
                      .where(person_organization_accounts: { organization_id: id })
    account_lists.find_each(batch_size: 1) do |account_list|
      account_list.contacts.find_each(batch_size: 5) { |contact| contact.merge_addresses }
    end
  end
end
