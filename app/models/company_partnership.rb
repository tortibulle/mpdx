class CompanyPartnership < ActiveRecord::Base
  belongs_to :account_list
  belongs_to :company
end
