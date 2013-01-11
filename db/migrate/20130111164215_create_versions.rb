class CreateVersions < ActiveRecord::Migration
  def self.up
    create_table :versions do |t|
      t.string   :item_type, :null => false
      t.integer  :item_id,   :null => false
      t.string   :event,     :null => false
      t.string   :whodunnit
      t.text     :object
      t.string   :related_object_type
      t.integer  :related_object_id
      t.datetime :created_at
    end
    add_index :versions, [:item_type, :item_id]
    add_index :versions, [:item_type, :item_id, :related_object_type, :related_object_id, :created_at], name: 'related_object_index'
  end

  def self.down
    remove_index :versions, [:item_type, :item_id]
    remove_index :versions, 'related_object_index'
    drop_table :versions
  end
end
