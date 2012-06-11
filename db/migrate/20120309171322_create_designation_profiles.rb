class DesignationAccount < ActiveRecord::Base
end

class CreateDesignationProfiles < ActiveRecord::Migration
  def change
    create_table :designation_profiles do |t|
      t.integer :remote_id
      t.belongs_to :user, null: false
      t.belongs_to :organization, null: false
      t.string :name

      t.timestamps
    end
    DesignationAccount.destroy_all
    add_column :designation_accounts, :designation_profile_id, :integer, null: false
    remove_column :designation_accounts, :profile
    add_index :designation_profiles, [:user_id, :organization_id, :name], unique: true, name: 'unique_name'
    add_index :designation_profiles, :organization_id
    add_index :designation_accounts, :designation_profile_id
  end
end
