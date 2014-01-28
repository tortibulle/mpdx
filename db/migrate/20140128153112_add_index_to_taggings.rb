class AddIndexToTaggings < ActiveRecord::Migration
  def change
    add_index :taggings, :taggable_id, name: 'INDEX_TAGGINGS_ON_TAGGABLE_ID'
  end
end
