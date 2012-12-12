class NotificationType < ActiveRecord::Base
  # attr_accessible :description, :type

  def initialize(*args)
    @contacts ||= {}
    super
  end
  def self.types
    @@types ||= connection.select_values("select distinct(type) from #{table_name}")
  end

  def self.check_all(designation_account)
    contacts = {}
    types.each do |type|
      contacts[type] = type.constantize.first.check(designation_account)
    end
    contacts
  end

  # Check to see if this designation_account has donations that should trigger a notification
  def check(designation_account)
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
