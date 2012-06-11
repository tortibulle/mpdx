class CreatePersonGoogleAccounts < ActiveRecord::Migration
  def change
    create_table :person_google_accounts do |t|
      t.string :remote_id
      t.belongs_to :person
      t.string :token
      t.string :refresh_token
      t.datetime :expires_at
      t.boolean :valid_token, default: false

      t.timestamps
    end
    add_index :person_google_accounts, :person_id

    add_column :person_twitter_accounts, :valid_token, :boolean, default: false
    add_column :person_facebook_accounts, :valid_token, :boolean, default: false
    add_column :person_linkedin_accounts, :valid_token, :boolean, default: false
  end
end
