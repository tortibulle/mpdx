class AddSyncInfoToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :last_synced, :datetime
    add_column :google_contacts, :last_etag, :string
    add_column :google_contacts, :last_data, :text
    add_column :google_contacts, :last_mappings, :text
    add_column :google_contacts, :overwrite_log, :text
  end
end
