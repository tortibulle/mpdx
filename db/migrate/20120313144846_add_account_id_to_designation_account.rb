class AddAccountIdToDesignationAccount < ActiveRecord::Migration
  def up
    add_column :designation_accounts, :account_id, :integer
    rename_column :designation_accounts, :account_number, :designation_number
  end

  def down
    rename_column :designation_accounts, :designation_number, :account_number
    remove_column :designation_accounts, :account_id
  end
end
