class CreateFamilyRelationships < ActiveRecord::Migration
  def change
    create_table :family_relationships do |t|
      t.belongs_to :person
      t.belongs_to :related_person
      t.string :relationship, null: false

      t.timestamps
    end
    add_index :family_relationships, [:person_id, :related_person_id], unique: true
    add_index :family_relationships, :related_person_id
  end
end
