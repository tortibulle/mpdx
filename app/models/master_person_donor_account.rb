class MasterPersonDonorAccount < ActiveRecord::Base
  belongs_to :master_person
  belongs_to :donor_account

  scope :primary, where(primary: true)

  before_save :make_first_donor_primary
  after_save :ensure_only_one_primary

  private
    def make_first_donor_primary
      self.primary ||= true if donor_account.master_person_donor_accounts.where(primary: true).blank?
    end

    def ensure_only_one_primary
      primary_donors = donor_account.master_person_donor_accounts.where(primary: true)
      primary_donors[0..-2].map {|e| e.update_column(:primary, false)} if primary_donors.length > 1
    end

end
