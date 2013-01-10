class AddDonationIdToNotification < ActiveRecord::Migration
  def change
    add_column :notifications, :donation_id, :integer
    add_index :notifications, [:contact_id, :notification_type_id, :donation_id], name: 'notification_index'
  end
end
