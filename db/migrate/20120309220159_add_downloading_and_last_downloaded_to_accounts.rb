class AddDownloadingAndLastDownloadedToAccounts < ActiveRecord::Migration
  def change
    add_column :person_facebook_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_facebook_accounts, :last_download, :datetime
    add_column :person_google_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_google_accounts, :last_download, :datetime
    add_column :person_key_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_key_accounts, :last_download, :datetime
    add_column :person_linkedin_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_linkedin_accounts, :last_download, :datetime
    add_column :person_organization_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_organization_accounts, :last_download, :datetime
    add_column :person_relay_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_relay_accounts, :last_download, :datetime
    add_column :person_twitter_accounts, :downloading, :boolean, default: false, null: false
    add_column :person_twitter_accounts, :last_download, :datetime
  end
end