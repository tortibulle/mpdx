class AddGroupImportToImports < ActiveRecord::Migration
  def change
    add_column :imports, :import_by_group, :boolean, default: false
    add_column :imports, :groups, :text
    add_column :imports, :group_tags, :text
  end
end
