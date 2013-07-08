class AddUncompletedTasksCountToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :uncompleted_tasks_count, :integer, default: 0, null: false
    Contact.find_each do |c|
      c.update_column(:uncompleted_tasks_count, c.tasks.uncompleted.count)
    end
  end
end
