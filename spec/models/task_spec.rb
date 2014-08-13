require 'spec_helper'

describe Task do
  let(:account_list) { create(:account_list) }
  it 'updates a related contacts uncompleted tasks count' do
    task1 = create(:task, account_list: account_list)
    task2 = create(:task, account_list: account_list)
    contact = create(:contact, account_list: account_list)
    contact.tasks << task1
    contact.tasks << task2
    contact.reload.uncompleted_tasks_count.should == 2

    task1.reload.update_attributes(completed: true)

    contact.reload.uncompleted_tasks_count.should == 1

    task1.update_attributes(completed: false)

    contact.reload.uncompleted_tasks_count.should == 2

    task2.destroy
    contact.reload.uncompleted_tasks_count.should == 1
  end

  context 'google calendar integration' do
    let(:google_integration) { double('GoogleIntegration', async: true) }

    before do
      AccountList.any_instance.stub(:google_integrations) { [google_integration] }
    end

    it 'does not sync an old task to google after a save call' do
      google_integration.should_not_receive(:lower_retry_async)

      create(:task, account_list: account_list, activity_type: 'Appointment')
    end

    it 'does not sync a completed task to google after a save call' do
      google_integration.should_not_receive(:lower_retry_async)

      create(:task, result: 'completed', account_list: account_list, activity_type: 'Appointment')
    end

    it 'syncs a task to google after a save call' do
      google_integration.should_receive(:lower_retry_async)

      create(:task, start_at: 1.day.from_now, account_list: account_list, activity_type: 'Appointment')
    end

    it 'syncs a task to google after a destroy call' do
      google_integration.should_receive(:lower_retry_async).twice

      create(:task, start_at: 1.day.from_now, account_list: account_list, activity_type: 'Appointment').destroy
    end
  end
end
