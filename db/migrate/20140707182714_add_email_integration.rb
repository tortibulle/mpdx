class AddEmailIntegration < ActiveRecord::Migration
  def change
    add_column :google_integrations, :email_integration, :boolean, null: false, default: false
  end
end
