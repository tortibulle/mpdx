class AddLastSyncedToGoogleIntegrations < ActiveRecord::Migration
  def change
    add_column :google_integrations, :last_synced, :datetime
  end
end
