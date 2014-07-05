class DesignationAccount < ActiveRecord::Base
  belongs_to :organization
  has_many :designation_profile_accounts, dependent: :destroy
  has_many :designation_profiles, through: :designation_profile_accounts

  has_many :account_list_entries, dependent: :destroy
  has_many :account_lists, through: :account_list_entries
  has_many :contacts, through: :account_lists
  has_many :donations, dependent: :destroy

  validates :organization_id, presence: true

  # attr_accessible :designation_number, :staff_account_id, :balance, :balance_updated_at

  def to_s() designation_number; end

  # A given user should only have a designation account in one list
  def account_list(user)
    (user.account_lists & account_lists).first
  end

  def update_donation_totals(donation)
    contacts.includes(:donor_accounts).where('donor_accounts.id' => donation.donor_account_id).each do |contact|
      contact.update_donation_totals(donation)
    end
  end
end
