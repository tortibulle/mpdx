class RemoveDesignationProfileIdFromAccountList < ActiveRecord::Migration
  def up
    remove_column :account_lists, :designation_profile_id
  end

  def down
    add_column :account_lists, :designation_profile_id, :integer
  end
end
