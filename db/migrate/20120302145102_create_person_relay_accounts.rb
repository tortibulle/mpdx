class CreatePersonRelayAccounts < ActiveRecord::Migration
  def change
    create_table :person_relay_accounts do |t|
      t.belongs_to :person
      t.string :remote_id
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :designation
      t.string :employee_id
      t.string :username
      t.boolean :authenticated, default: false, null: false

      t.timestamps
    end
    add_column :person_facebook_accounts, :authenticated, :boolean, default: false, null: false
    add_index :person_facebook_accounts, [:remote_id, :authenticated], :unique => true

    add_column :person_google_accounts, :authenticated, :boolean, default: false, null: false
    add_index :person_google_accounts, [:remote_id, :authenticated], :unique => true

    add_column :person_twitter_accounts, :authenticated, :boolean, default: false, null: false
    add_index :person_twitter_accounts, [:remote_id, :authenticated], :unique => true

    add_column :person_linkedin_accounts, :authenticated, :boolean, default: false, null: false
    add_index :person_linkedin_accounts, [:remote_id, :authenticated], :unique => true

    add_index :person_relay_accounts, :person_id
    add_index :person_relay_accounts, [:remote_id, :authenticated], :unique => true
  end
end
