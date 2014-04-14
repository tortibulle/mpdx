require 'spec_helper'

describe GoogleCalendarIntegrator do
  let(:google_integration) { build(:google_integration, calendar_integrations: ['Appointment']) }
  let(:integrator) { GoogleCalendarIntegrator.new(google_integration) }
  let(:task) { create(:task, activity_type: 'Appointment') }

  context '#sync_tasks' do
    it 'calls #sync_task for each future, uncompleted task that is set to be synced' do
      task1, task2 = double, double

      google_integration.stub_chain(:account_list, :tasks, :future, :uncompleted, :of_type).and_return([task1, task2])
      integrator.should_receive(:sync_task).with(task1).and_return
      integrator.should_receive(:sync_task).with(task2).and_return

      integrator.sync_tasks
    end
  end

  context '#sync_task' do
    it 'calls add_task if no google_event exists' do

      integrator.should_receive(:add_task).with(task)

      integrator.sync_task(task)
    end
  end

  context '#add_task' do
    it 'creates a google_event' do
      stub_request(:get, 'https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest')
      google_integration.stub_chain(:calendar_api, :events, :insert).and_return('')
      integrator.client.should_receive(:execute).and_return(double(data: {'id' => 'foo'}, status: 200))
      integrator.should_receive(:event_attributes).and_return({})

      expect {
        integrator.add_task(task)
      }.to change(GoogleEvent, :count)
    end
  end
end
