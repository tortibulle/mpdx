class CreateGoogleEvents < ActiveRecord::Migration
  def change
    create_table :google_events do |t|
      t.belongs_to :activity, index: true
      t.belongs_to :google_integration, index: true
      t.string :google_event_id

      t.timestamps
    end

    remove_column :activities, :google_event_id, :string
  end
end
