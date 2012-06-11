class CreateDesignationProfileAccounts < ActiveRecord::Migration
  def change
    create_table :designation_profile_accounts do |t|
      t.belongs_to :designation_profile
      t.belongs_to :designation_account

      t.timestamps
    end
    add_index :designation_profile_accounts, [:designation_profile_id, :designation_account_id], unique: true, name: 'designation_p_to_a'
  end
end
