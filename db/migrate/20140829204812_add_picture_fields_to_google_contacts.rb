class AddPictureFieldsToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :picture_etag, :string
    add_column :google_contacts, :picture_id, :integer
  end
end
