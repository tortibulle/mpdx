class Appeal < ActiveRecord::Base
  belongs_to :account_list
  has_many :contacts, through: :appeal_contacts
end
