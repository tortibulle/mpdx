class ContactPersonShouldBeUnique < ActiveRecord::Migration
  def up
    remove_index :contact_people, :contact_id
    add_index :contact_people, [:contact_id, :person_id], unique: true
  end

  def down
    add_index :contact_people, :contact_id
    remove_index :contact_people, [:contact_id, :person_id]
  end
end
