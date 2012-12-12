class DonorAccountPerson < ActiveRecord::Base
  belongs_to :donor_account
  belongs_to :person
  # attr_accessible :title, :body
end
