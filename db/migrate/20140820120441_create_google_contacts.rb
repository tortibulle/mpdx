class CreateGoogleContacts < ActiveRecord::Migration
  def change
    create_table :google_contacts do |t|
      t.string   "remote_id"
      t.integer  "person_id"
      t.timestamps
    end
    add_index :google_contacts, :remote_id
    add_index :google_contacts, :person_id
  end
end
