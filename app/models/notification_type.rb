class NotificationType < ActiveRecord::Base
  # attr_accessible :description, :type

  def initialize(*args)
    @contacts ||= {}
    super
  end
  def self.types
    @@types ||= connection.select_values("select distinct(type) from #{table_name}")
  end

  def self.check_all(account_list)
    contacts = {}
    types.each do |type|
      type_instance = type.constantize.first
      actions = account_list.notification_preferences.find_by_notification_type_id(type_instance.id).try(:actions)
      if (Array.wrap(actions) & NotificationPreference.default_actions).present?
        contacts[type] = type_instance.check(account_list)
      end
    end
    contacts
  end

  # Check to see if this designation_account has donations that should trigger a notification
  def check(account_list)
    raise 'This method needs to be implemented in a subclass'
  end

  # Create a task that corresponds to this notification
  def create_task(account_list, contact)
    raise 'This method needs to be implemented in a subclass'
  end

  def add_contact(notification_type, contact)
    @notifications[notification_type] ||= []
    @notifications[notification_type] << contact
  end

end
