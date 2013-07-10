class MigrateTntTaskIdsToRemoteIdAndSource < ActiveRecord::Migration
  def up
    Activity.where("tnt_id is not null and tnt_id <> ''").update_all("remote_id = tnt_id, source = 'tnt'")
    remove_column :activities, :tnt_id
  end

  def down
    raise
  end
end
