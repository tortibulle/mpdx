class CreateNotificationPreferences < ActiveRecord::Migration
  def change
    create_table :notification_preferences do |t|
      t.integer :notification_type_id
      t.integer :account_list_id
      t.text :actions

      t.timestamps
    end
    
    add_index :notification_preferences, :account_list_id
    add_index :notification_preferences, :notification_type_id
  end
end