class AddUserIdToImport < ActiveRecord::Migration
  def change
    add_column :imports, :user_id, :integer
    add_index :imports, :user_id
  end
end
