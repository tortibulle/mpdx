require_dependency 'data_server'
require_dependency 'credential_validator'
require 'async'

class Person::OrganizationAccount < ActiveRecord::Base
  include Person::Account
  include Async
  include Sidekiq::Worker
  sidekiq_options retry: false, unique: true

  serialize :password, Encryptor.new

  after_create :set_up_account_list, :queue_import_data
  validates :organization_id, :person_id, presence: true
  validates :username, :password, presence: { if: :requires_username_and_password? }
  validates_with CredentialValidator
  after_validation :set_valid_credentials
  after_destroy :destroy_designation_profiles

  # attr_accessible :username, :password, :organization, :organization_id

  belongs_to :organization

  def to_s
    str = organization.to_s
    postfix = username || remote_id
    str += ': ' + postfix if postfix
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

  def import_all_data
    return if locked_at || new_record? || !valid_credentials
    update_column(:downloading, true)
    begin
      # we only want to set the last_download date if at least one donation was downloaded
      starting_donation_count = user.donations.count

      update_attributes(downloading: true, locked_at: Time.now)
      date_from = last_download ? (last_download - 2.week) : ''
      organization.api(self).import_all(date_from)

      ending_donation_count = user.donations.count

      if ending_donation_count - starting_donation_count > 0
        # If this is the first time downloading, update the financial status of partners
        account_list.update_partner_statuses if last_download.nil? && account_list

        # Set the last download date to whenever the last donation was received
        update_column(:last_download, user.donations.order('donation_date desc').first.donation_date)
      end
    rescue OrgAccountInvalidCredentialsError
      update_column(:valid_credentials, false)
      ImportMailer.credentials_error(self).deliver
    ensure
      begin
        update_column(:downloading, false)
        update_column(:locked_at, nil)
      rescue ActiveRecord::ActiveRecordError
      end
    end
  end

  private

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
    if user.account_lists.reload.empty? || organization.designation_profiles.where(user_id: person_id).blank?
      account_list = user.account_lists.create!(name: user.to_s, creator_id: user.id)
      organization.designation_profiles.create!(name: user.to_s, user_id: user.id, account_list_id: account_list.id)
    end
  end

  def destroy_designation_profiles
    designation_profiles.destroy_all
  end
end
