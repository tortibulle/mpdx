class AddOverrideToImport < ActiveRecord::Migration
  def change
    add_column :imports, :override, :boolean, default: false, null: false
  end
end
