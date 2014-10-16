class AddLastSyncedToGoogleIntegrations < ActiveRecord::Migration
  def change
    add_column :google_integrations, :contacts_last_synced, :datetime
  end
end
