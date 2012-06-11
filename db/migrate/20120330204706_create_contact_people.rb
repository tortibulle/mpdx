class CreateContactPeople < ActiveRecord::Migration
  def change
    create_table :contact_people do |t|
      t.belongs_to :contact
      t.belongs_to :person
      t.boolean :primary

      t.timestamps
    end
    add_index :contact_people, :contact_id
    add_index :contact_people, :person_id
  end
end
