class CreateHelpRequests < ActiveRecord::Migration
  def change
    create_table :help_requests do |t|
      t.string :name
      t.text :browser
      t.text :problem
      t.string :email
      t.string :file
      t.integer :user_id
      t.integer :account_list_id
      t.text :session
      t.text :user_preferences
      t.text :account_list_settings
      t.string :request_type

      t.timestamps
    end
  end
end
