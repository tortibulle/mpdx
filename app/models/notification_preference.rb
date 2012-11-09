class NotificationPreference < ActiveRecord::Base
  belongs_to :account_list

  serialize :actions
  attr_accessible :actions, :notification_type_id
  validates_presence_of :actions, :notification_type_id, presence: true
end
