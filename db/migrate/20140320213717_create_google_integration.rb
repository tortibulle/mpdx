class CreateGoogleIntegration < ActiveRecord::Migration
  def change
    create_table :google_integrations do |t|
      t.belongs_to :account_list, index: true
      t.belongs_to :google_account, index: true
      t.boolean :calendar_integration, null: false, default: false
      t.text :calendar_integrations
      t.string :calendar_id
      t.string :calendar_name
    end

    add_column :activities, :google_event_id, :string
  end
end
