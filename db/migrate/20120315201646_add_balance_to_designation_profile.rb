class AddBalanceToDesignationProfile < ActiveRecord::Migration
  def change
    add_column :designation_profiles, :balance, :decimal, precision: 8, scale: 2
    add_column :designation_profiles, :balance_updated_at, :datetime
    add_column :designation_accounts, :balance_updated_at, :datetime
    remove_index :designation_accounts, :organization_id
    add_index :designation_accounts, [:organization_id, :designation_number], name: 'unique_designation_org', unique: true
    add_index :donations, :donation_date
  end
end
