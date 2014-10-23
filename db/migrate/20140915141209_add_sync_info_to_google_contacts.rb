class AddSyncInfoToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :last_synced, :datetime
    add_column :google_contacts, :last_etag, :string
    add_column :google_contacts, :last_data, :text
  end
end
