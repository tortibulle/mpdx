class AddContactIdToGoogleContacts < ActiveRecord::Migration
  def change
    add_column :google_contacts, :contact_id, :integer
  end
end
