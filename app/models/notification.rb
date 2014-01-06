class Notification < ActiveRecord::Base
  belongs_to :contact, inverse_of: :notifications
  belongs_to :notification_type
  belongs_to :donation
  has_many :tasks, inverse_of: :notification, dependent: :destroy
  # attr_accessible :event_date, :cleared, :notification_type_id

  scope :active, -> { where(cleared: false) }
end
