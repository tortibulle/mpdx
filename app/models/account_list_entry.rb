class AccountListEntry < ActiveRecord::Base
  belongs_to :account_list
  belongs_to :designation_account
end
