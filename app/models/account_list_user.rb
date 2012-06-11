class AccountListUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :account_list
end
