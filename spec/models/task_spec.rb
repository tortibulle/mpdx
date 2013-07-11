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
    task1.send(:update_contact_uncompleted_tasks_count)

    contact.reload.uncompleted_tasks_count.should == 1
  end
end
