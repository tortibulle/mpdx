class ChangeTypeOfRemoteIdFromDesignationProfile < ActiveRecord::Migration
  def up
    change_column :designation_profiles, :remote_id, :string
  end

  def down
    change_column :designation_profiles, :remote_id, :integer
  end
end
