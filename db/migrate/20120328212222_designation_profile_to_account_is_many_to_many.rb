class DesignationProfileToAccountIsManyToMany < ActiveRecord::Migration
  def up
    remove_column :designation_accounts, :designation_profile_id
  end

  def down
    add :designation_accounts, :designation_profile_id, :integer
  end
end
