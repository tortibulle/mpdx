class AddEmailIntegration < ActiveRecord::Migration
  def change
    add_column :google_integrations, :email_integration, :boolean, null: false, default: false

    create_table :google_emails do |t|
      t.integer :google_account_id
      t.integer :google_email_id, limit: 8
      t.timestamps
    end

    create_table :google_email_activities do |t|
      t.integer :google_email_id
      t.integer :activity_id
      t.timestamps
    end
  end
end
