class CreateMasterPersonSources < ActiveRecord::Migration
  def change
    create_table :master_person_sources do |t|
      t.belongs_to :master_person
      t.belongs_to :organization
      t.string :remote_id

      t.timestamps
    end
    add_index :master_person_sources, [:organization_id, :remote_id], unique: true, name: 'organization_remote_id'
  end
end
