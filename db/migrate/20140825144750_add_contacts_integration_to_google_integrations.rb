class AddContactsIntegrationToGoogleIntegrations < ActiveRecord::Migration
  def change
    add_column :google_integrations, :contacts_integration, :boolean
  end
end
