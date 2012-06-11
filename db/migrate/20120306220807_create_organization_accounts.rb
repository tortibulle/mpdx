class CreateOrganizationAccounts < ActiveRecord::Migration
  def change
    create_table :organization_accounts do |t|
      t.belongs_to :user
      t.belongs_to :organization
      t.string :username
      t.string :password

      t.timestamps
    end
    add_index :organization_accounts, [:user_id, :organization_id], unique: true
  end
end
