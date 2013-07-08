class AddDeletedToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :deleted, :boolean, null: false, default: false
  end
end
