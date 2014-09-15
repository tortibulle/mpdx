class DesignationProfile < ActiveRecord::Base
  belongs_to :user
  belongs_to :organization
  has_many :designation_profile_accounts, dependent: :destroy
  has_many :designation_accounts, through: :designation_profile_accounts
  belongs_to :account_list

  scope :for_org, -> (org_id) { where(organization_id: org_id) }

  def to_s() name; end

  def designation_account
    designation_accounts.first
  end

  def merge(other)
    DesignationProfile.transaction do
      other.designation_profile_accounts.each do |da|
        designation_profile_accounts << da unless designation_profile_accounts.find { |dpa| dpa.designation_account_id == da.designation_account_id }
      end

      other.reload
      other.destroy

      save(validate: false)
    end
  end
end
