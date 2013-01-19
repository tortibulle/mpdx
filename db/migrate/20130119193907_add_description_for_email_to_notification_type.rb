class AddDescriptionForEmailToNotificationType < ActiveRecord::Migration
  def change
    add_column :notification_types, :description_for_email, :text
  end
end
