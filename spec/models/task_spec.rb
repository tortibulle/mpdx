require 'spec_helper'

describe Task do
  let(:account_list) { create(:account_list) }
  it "updates a related contacts uncompleted tasks count" do
    task1 = create(:task, account_list: account_list)
    task2 = create(:task, account_list: account_list)
    contact = create(:contact, account_list: account_list)
    contact.tasks << task1
    contact.tasks << task2
    contact.reload.uncompleted_tasks_count.should == 2

    task1.reload.update_attributes(completed: true)
    #task1.send(:update_contact_uncompleted_tasks_count)

    contact.reload.uncompleted_tasks_count.should == 1

    task1.update_attributes(completed: false)

    contact.reload.uncompleted_tasks_count.should == 2

    task2.destroy
    contact.reload.uncompleted_tasks_count.should == 1
  end

  it "#overdue should only include uncompleted tasks" do
    history_task =  create(:task, account_list: account_list, start_at: Time.now.beginning_of_day - 1.day, completed: true)
    overdue_task = create(:task, account_list: account_list, start_at: Time.now.beginning_of_day - 1.day)

    overdue_tasks = account_list.tasks.overdue

    overdue_tasks.should include overdue_task
    overdue_tasks.should_not include history_task
  end
end
