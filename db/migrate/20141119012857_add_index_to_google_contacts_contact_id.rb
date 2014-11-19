class AddIndexToGoogleContactsContactId < ActiveRecord::Migration
  def change
    add_index :google_contacts, :contact_id
    add_index :google_contacts, [:person_id, :contact_id]
  end
end
