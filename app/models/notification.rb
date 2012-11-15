class Notification < ActiveRecord::Base
  belongs_to :contact, inverse_of: :notifications
  belongs_to :notification_type
  has_many :tasks, inverse_of: :notification
  attr_accessible :event_date, :cleared, :notification_type_id

  scope :active, where(cleared: false)
end
