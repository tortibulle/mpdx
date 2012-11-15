class Donation < ActiveRecord::Base
  belongs_to :donor_account
  belongs_to :designation_account

  validates :amount, :donation_date, presence: true

  scope :for, lambda { |designation_account| where(designation_account_id: designation_account.id) }
  scope :since, lambda { |date| where("donation_date > ?", date) }

  default_scope order("donation_date desc")

  after_create :update_totals

  private
    def update_totals
      donor_account.update_donation_totals(self)
      designation_account.update_donation_totals(self)
    end
end
