class CreateMasterPersonDonorAccounts < ActiveRecord::Migration
  def change
    create_table :master_person_donor_accounts do |t|
      t.belongs_to :master_person
      t.belongs_to :donor_account
      t.boolean :primary, null: false, default: false

      t.timestamps
    end
    add_index :master_person_donor_accounts, [:master_person_id, :donor_account_id], unique: true, name: 'person_account'
    add_index :master_person_donor_accounts, :donor_account_id
  end
end
