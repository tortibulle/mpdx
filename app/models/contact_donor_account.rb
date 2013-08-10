class ContactDonorAccount < ActiveRecord::Base
  belongs_to :contact, inverse_of: :contact_donor_accounts
  belongs_to :donor_account, inverse_of: :contact_donor_accounts

  validate :ensure_one_contact_per_donor_account_number

  def ensure_one_contact_per_donor_account_number
    if contact.account_list.donor_accounts.where(account_number: donor_account.account_number).first
      contact.errors.add(:base, _("Another contact on your accout already has the donor account number you've tried to assign to this contact."))
      false
    end
    true
  end
end
