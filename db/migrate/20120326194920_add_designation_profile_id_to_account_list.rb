class AddDesignationProfileIdToAccountList < ActiveRecord::Migration
  def change
    add_column :account_lists, :designation_profile_id, :integer
    add_index :account_lists, [:designation_profile_id], :unique => true
    add_column :designation_accounts, :name, :string
  end
end