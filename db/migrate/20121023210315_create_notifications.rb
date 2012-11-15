class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.belongs_to :contact
      t.belongs_to :notification_type
      t.datetime :event_date
      t.boolean :cleared, default: false, null: false

      t.timestamps
    end
    add_index :notifications, :contact_id
    add_index :notifications, :notification_type_id

  end
end
