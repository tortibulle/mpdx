class ChangeProfileIndex < ActiveRecord::Migration
  def up
    remove_index :designation_profiles, name: :unique_name
    add_index :designation_profiles, [:user_id, :organization_id, :remote_id], name: :unique_remote_id, unique: true
  end

  def down
  end
end
