class ContactDonorAccount < ActiveRecord::Base
  belongs_to :contact
  belongs_to :donor_account
end
