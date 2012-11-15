class AddNotificationIdToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :notification_id, :integer
    add_index :activities, :notification_id
  end
end
