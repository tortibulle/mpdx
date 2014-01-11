class AddSubscribedToUpdatesToPerson < ActiveRecord::Migration
  def change
    add_column :people, :subscribed_to_updates, :boolean
  end
end
