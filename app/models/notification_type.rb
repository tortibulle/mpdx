class NotificationType < ActiveRecord::Base
  attr_accessible :description, :type


  def self.types
    connection.select_values("select distinct(type) from #{table_name}")
  end
end
