class AddActionToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :next_action, :string
  end
end
