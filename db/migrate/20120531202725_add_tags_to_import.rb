class AddTagsToImport < ActiveRecord::Migration
  def change
    add_column :imports, :tags, :text
  end
end
