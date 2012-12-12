class ContactDonorAccount < ActiveRecord::Base
  belongs_to :contact
  belongs_to :donor_account
  # attr_accessible :contact_id, :donor_account_id
end
