class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.belongs_to :contact
      t.belongs_to :notification_type
      t.datetime :event_date

      t.timestamps
    end
    add_index :notifications, :contact_id
    add_index :notifications, :notification_type_id
    
    add_column :contacts, :last_checked_notifications_at, :datetime
  end
end