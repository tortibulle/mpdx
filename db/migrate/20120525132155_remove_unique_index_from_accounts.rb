class RemoveUniqueIndexFromAccounts < ActiveRecord::Migration
  def up
    remove_index :person_facebook_accounts, name: 'index_person_facebook_accounts_on_remote_id_and_authenticated'
    remove_index :person_google_accounts, name: 'index_person_google_accounts_on_remote_id_and_authenticated'
    remove_index :person_key_accounts, name: 'index_person_key_accounts_on_remote_id_and_authenticated'
    remove_index :person_linkedin_accounts, name: 'index_person_linkedin_accounts_on_remote_id_and_authenticated'
    remove_index :person_relay_accounts, name: 'index_person_relay_accounts_on_remote_id_and_authenticated'
    remove_index :person_twitter_accounts, name: 'index_person_twitter_accounts_on_remote_id_and_authenticated'


    add_index :person_relay_accounts, :remote_id
    add_index :person_key_accounts, :remote_id
    add_index :person_google_accounts, :remote_id
  end

  def down
    add_index :person_twitter_accounts, [:remote_id, :authenticated], unique: true
    add_index :person_relay_accounts, [:remote_id, :authenticated], unique: true
    add_index :person_linkedin_accounts, [:remote_id, :authenticated], unique: true
    add_index :person_key_accounts, [:remote_id, :authenticated], unique: true
    add_index :person_google_accounts, [:remote_id, :authenticated], unique: true
    add_index :person_facebook_accounts, [:remote_id, :authenticated], unique: true
  end
end
