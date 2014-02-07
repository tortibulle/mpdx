class AddSourceAccountIdToImport < ActiveRecord::Migration
  def change
    add_column :imports, :source_account_id, :integer
  end
end
