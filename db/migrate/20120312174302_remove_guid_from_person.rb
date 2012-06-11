class RemoveGuidFromPerson < ActiveRecord::Migration
  def up
    remove_column :people, :guid
    add_column :people, :middle_name, :string
  end

  def down
    remove_column :people, :middle_name
    add_column :people, :guid, :string
  end
end
