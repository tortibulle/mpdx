class AddFieldsToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :picture_etag, :string
    add_column :google_contacts, :picture_id, :integer

    add_column :google_contacts, :google_account_id, :integer
    add_index :google_contacts, :google_account_id
  end
end
