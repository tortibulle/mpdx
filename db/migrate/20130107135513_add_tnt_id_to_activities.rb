class AddTntIdToActivities < ActiveRecord::Migration
  def change
    add_column :activities, :tnt_id, :string
    add_index :activities, :tnt_id
  end
end
