class CreateMasterPeople < ActiveRecord::Migration
  def change
    create_table :master_people do |t|

      t.timestamps
    end
    add_column :people, :master_person_id, :integer, :null => false
    add_index :people, :master_person_id
  end
end
