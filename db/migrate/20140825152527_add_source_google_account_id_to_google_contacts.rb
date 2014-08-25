class AddSourceGoogleAccountIdToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :source_google_account_id, :integer
    add_index :google_contacts, :source_google_account_id
  end
end
