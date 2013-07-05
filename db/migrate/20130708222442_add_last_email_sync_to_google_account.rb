class AddLastEmailSyncToGoogleAccount < ActiveRecord::Migration
  def change
    add_column :person_google_accounts, :last_email_sync, :datetime
  end
end
