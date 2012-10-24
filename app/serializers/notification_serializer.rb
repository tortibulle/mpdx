class NotificationSerializer < ActiveModel::Serializer
  attributes :id, :event_date
  has_one :contact
  has_one :notification_type
end
