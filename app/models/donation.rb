class Donation < ActiveRecord::Base
  belongs_to :donor_account
  belongs_to :designation_account

  validates :amount, :donation_date, presence: true

  default_scope order("donation_date desc")

  after_create :update_totals

  private
    def update_totals
      donor_account.update_donation_totals(self)
      designation_account.update_donation_totals(self)
    end
end
