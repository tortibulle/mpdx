class AddMoreIndexes < ActiveRecord::Migration
  def change
    add_index :versions, [:item_type, :event, :related_object_type, :related_object_id, :created_at, :item_id], name: 'index_versions_on_item_type'
    add_index :master_person_sources, :master_person_id
  end
end
