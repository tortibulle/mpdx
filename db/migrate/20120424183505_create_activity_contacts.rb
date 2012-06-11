class CreateActivityContacts < ActiveRecord::Migration
  def change
    create_table :activity_contacts do |t|
      t.belongs_to :activity
      t.belongs_to :contact

      t.timestamps
    end
    add_index :activity_contacts, [:activity_id, :contact_id]
    add_index :activity_contacts, :contact_id
  end
end
