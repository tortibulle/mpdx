require 'spec_helper'

describe Task do
  it "updates a related contacts uncompleted tasks count" do
    task1 = create(:task)
    task2 = create(:task)
    contact = create(:contact)
    contact.tasks << task1
    contact.tasks << task2
    contact.reload.uncompleted_tasks_count.should == 2

    task1.update_attributes(completed: true)

    contact.reload.uncompleted_tasks_count.should == 1

    task1.update_attributes(completed: false)

    contact.reload.uncompleted_tasks_count.should == 2

    task2.destroy
    contact.reload.uncompleted_tasks_count.should == 1
  end
end
