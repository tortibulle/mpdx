class CreateDonorAccounts < ActiveRecord::Migration
  def change
    create_table :donor_accounts do |t|
      t.belongs_to :organization
      t.string :account_number
      t.string :name

      t.timestamps
    end
    add_index :donor_accounts, :organization_id
  end
end
