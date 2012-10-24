class Notification < ActiveRecord::Base
  belongs_to :contact
  belongs_to :notification_type
  attr_accessible :event_date
end
