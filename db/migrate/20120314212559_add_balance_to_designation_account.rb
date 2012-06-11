class AddBalanceToDesignationAccount < ActiveRecord::Migration
  def change
    add_column :designation_accounts, :balance, :decimal, precision: 8, scale: 2
    remove_column :designation_accounts, :account_id
  end
end
