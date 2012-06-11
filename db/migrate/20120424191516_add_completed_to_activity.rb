class AddCompletedToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :completed, :boolean, null: false, default: false
    remove_column :activities, :description

  end
end
