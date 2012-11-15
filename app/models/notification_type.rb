class NotificationType < ActiveRecord::Base
  attr_accessible :description, :type
  attr_reader :notifications


  def initialize(*args)
    @notifications ||= []
    super
  end
  def self.types
    @@types ||= connection.select_values("select distinct(type) from #{table_name}")
  end

  # Check to see if this designation_account has donations that should trigger a notification
  def process(designation_account)
    raise 'This method needs to be implemented in a subclass'
  end

  def add_notification(type, designation_account)
    notifications << {type: type, designation_account: designation_account}
  end

end
