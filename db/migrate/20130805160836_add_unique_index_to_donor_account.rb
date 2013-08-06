class AddUniqueIndexToDonorAccount < ActiveRecord::Migration
  def change
    add_index :donor_accounts, [:organization_id, :account_number], unique: true
  end
end
