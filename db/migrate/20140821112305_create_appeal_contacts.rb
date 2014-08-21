class CreateAppealContacts < ActiveRecord::Migration
  def change
    create_table :appeal_contacts do |t|
      t.belongs_to :appeal
      t.belongs_to :contact

      t.timestamps
    end
    add_index :appeal_contacts, [:appeal_id, :contact_id]
    add_index :appeal_contacts, :contact_id
  end
end
