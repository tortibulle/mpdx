class MoveDeceasedColumnToPerson < ActiveRecord::Migration
  def up
    add_column :people, :deceased, :boolean, default: false, null: false
    Contact.where(deceased: true).find_each do |c|
      c.people.each do |p|
        p.update_column(:deceased, true)
      end
    end
    remove_column :contacts, :deceased
  end

  def down
    add_column :contats, :deceased, :boolean, default: false, null: false
    Person.where(deceased: true).find_each do |p|
      p.contact.update_column(:deceased, true)
    end
    remove_column :people, :deceased
  end
end
