class Donation < ActiveRecord::Base
  belongs_to :donor_account
  belongs_to :designation_account

  validates :amount, :donation_date, presence: true

  # attr_accessible :donor_account_id, :motivation, :payment_method, :tendered_currency, :donation_date, :amount, :tendered_amount, :currency, :channel, :payment_type

  scope :for, -> (designation_account) { where(designation_account_id: designation_account.id) }
  scope :for_accounts, -> (designation_accounts) { where(designation_account_id: designation_accounts.pluck(:id)) }
  scope :since, -> (date) { where('donation_date > ?', date) }

  default_scope -> { order('donation_date desc') }

  after_create :update_totals
  before_validation :set_amount_from_tendered_amount

  private
    def update_totals
      donor_account.update_donation_totals(self)
      designation_account.update_donation_totals(self) if designation_account
    end

    def set_amount_from_tendered_amount
      if tendered_amount.present?
        self.tendered_amount = tendered_amount_before_type_cast.to_s.gsub(/[^\d\.\-]+/, '').to_f
        self.amount ||= tendered_amount_before_type_cast
      end
    end
end
