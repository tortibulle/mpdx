class AddPrimaryToSomeAccounts < ActiveRecord::Migration
  def change
    add_column :person_twitter_accounts, :primary, :boolean, default: false
    add_column :person_google_accounts, :primary, :boolean, default: false
    add_column :person_relay_accounts, :primary, :boolean, default: false
    add_column :person_key_accounts, :primary, :boolean, default: false
  end
end