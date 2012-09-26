class AddCompletedAtToActivity < ActiveRecord::Migration
  def change
    add_column :activities, :completed_at, :datetime
    Task.connection.update("UPDATE activities SET completed_at = updated_at WHERE type = 'Task' AND completed = 't'")
  end
end
