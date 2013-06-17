require_dependency 'data_server'
require_dependency 'credential_validator'
require 'async'

class Person::OrganizationAccount < ActiveRecord::Base
  extend Person::Account
  include Async
  include Sidekiq::Worker
  sidekiq_options retry: false

  serialize :password, Encryptor.new

  after_create :set_up_account_list, :queue_import_data
  validates :organization_id, :person_id, presence: true
  validates :username, :password, :presence => {if: :requires_username_and_password?}
  validates_with CredentialValidator
  after_validation :set_valid_credentials

  # attr_accessible :username, :password, :organization, :organization_id

  belongs_to :organization

  def to_s
    str = organization.to_s
    str += ': ' + (username || remote_id)
    str
  end

  def user
    @user ||= person.to_user
  end

  def self.one_per_user?() false; end

  def requires_username_and_password?
    organization.api(self).requires_username_and_password? if organization
  end

  def queue_import_data
    async(:import_all_data)
  end

  def account_list
    user.designation_profiles.first.try(:account_list)
  end

  def designation_profiles
    DesignationProfile.where(organization_id: organization_id, user_id: person_id)
  end

  private
  def import_all_data
    return if locked_at
    update_column(:downloading, true)
    begin
      # we only want to set the last_download date if at least one donation was downloaded
      starting_donation_count = user.designation_profiles.where(organization_id: organization_id).collect(&:designation_accounts).flatten.sum { |da| da.donations.count }

      update_attributes({downloading: true, locked_at: Time.now}, without_protection: true)
      date_from = last_download ? (last_download - 2.week).strftime("%m/%d/%Y") : ''
      organization.api(self).import_all(date_from)

      ending_donation_count = user.designation_profiles.where(organization_id: organization_id).collect(&:designation_accounts).flatten.sum { |da| da.donations.count }

      if ending_donation_count - starting_donation_count > 0
        # If this is the first time downloading, update the financial status of partners
        account_list.update_partner_statuses if last_download.nil? && account_list

        update_column(:last_download, Time.now)
      end
    ensure
      update_attributes({downloading: false, locked_at: nil}, without_protection: true)
    end
  end

  def set_valid_credentials
    self.valid_credentials = true
  end

  # The purpose of this method is to transparently share one account list between two spouses.
  # In general any time two people have access to a designation profile containing only one
  # designation account, the second person will be given access to the first person's account list
  def set_up_account_list
    begin
      organization.api(self).import_profiles
    rescue DataServerError => e
      Airbrake.notify(e)
    end
    # If this org account doesn't have any profiles, create a default account list and profile for them
    if user.account_lists.reload.empty?
      account_list = user.account_lists.create({name: user.to_s, creator_id: user.id}, without_protection: true)
      organization.designation_profiles.create({name: user.to_s, user_id: user.id, account_list_id: account_list.id}, without_protection: true)
    end
  end
end
