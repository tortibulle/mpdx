class AddIndexToNotifications < ActiveRecord::Migration
  def change
    add_index :notifications, :donation_id
  end
end
