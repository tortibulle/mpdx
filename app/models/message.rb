class Message < ActiveRecord::Base
  belongs_to :from, class_name: 'Person'
  belongs_to :to, class_name: 'Person'
  belongs_to :contact
  belongs_to :account_list
end
