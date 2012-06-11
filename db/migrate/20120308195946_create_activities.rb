class CreateActivities < ActiveRecord::Migration
  def change
    create_table :activities do |t|
      t.belongs_to :account_list
      t.boolean :starred, default: false, null: false
      t.string :location
      t.string :subject
      t.text :description
      t.datetime :start_at
      t.datetime :end_at
      t.string :type

      t.timestamps
    end
    add_index :activities, :account_list_id
    add_index :activities, :start_at
  end
end