require 'spec_helper'

describe GoogleIntegration do
  let(:google_integration) { build(:google_integration) }
  let(:calendar_data) { Hashie::Mash.new(JSON.parse(%q|{"kind":"calendar#calendarList","etag":"\"brXLH9dIsANhw0fUafNoxUtvJn8/z-s-EUrs3E9y8jAlApPmQlV5S88\"","items":[{"kind":"calendar#calendarListEntry","etag":"\"brXLH9dIsANhw0fUafNoxUtvJn8/wj94O5gU621uu4faAu06IKOk9jk\"","id":"f4r590q526okeq1osnv5bt6fd8@group.calendar.google.com","summary":"WebandMobileDevelopmentTeam","description":"Thiscalendarcanbeusedtotrackteammembers'vacation/leaverequests","timeZone":"America/New_York","colorId":"12","backgroundColor":"#fad165","foregroundColor":"#000000","selected":true,"accessRole":"owner"}]}|)) }

  context '#queue_sync_data' do
    it 'queues a data sync when an integration type is passed in' do
      expect {
        google_integration.queue_sync_data('calendar')
      }.to change(GoogleIntegration.jobs, :size).by(1)
    end

    it 'does not queue a data sync when an integration type is passed in' do
      expect {
        google_integration.queue_sync_data
      }.to_not change(GoogleIntegration.jobs, :size)
    end
  end

  context '#sync_data' do
    it 'triggers a calendar_integration sync' do
      google_integration.calendar_integrator.should_receive(:sync_tasks)

      google_integration.sync_data('calendar')
    end
  end

  context '#calendar_integrator' do
    it 'should return the same GoogleCalendarIntegrator instance across multiple calls' do
      expect(google_integration.calendar_integrator).to equal(google_integration.calendar_integrator)
    end
  end

  context '#calendars' do
    let(:calendar_list_api) { double }
    let(:client) { double(execute: double(data: calendar_data)) }

    it 'returns a list of calendars from google' do
      google_integration.google_account.stub(:client).and_return(client)
      google_integration.stub_chain(:calendar_api, :calendar_list, :list).and_return(calendar_list_api)

      client.should_receive(:execute).with(:api_method => calendar_list_api,
                                           :parameters => {'userId' => 'me'})

      google_integration.calendars.should == [calendar_data.items.first]
    end
  end
  
  context '#toggle_calendar_integration_for_appointments' do
    before do
      google_integration.calendar_integrations = []
      google_integration.calendar_integration = true
      google_integration.save!
    end

    it 'turns on Appointment syncing if calendar_integration is enabled and nothing is specified' do
      expect(google_integration.calendar_integrations).to eq(['Appointment'])
    end

    it 'remove calendar_integrations when calendar_integration is set to false' do
      google_integration.calendar_integrations = ['Appointment']
      google_integration.calendar_integration = false
      google_integration.save
      expect(google_integration.calendar_integrations).to eq([])
    end
  end

  context '#set_default_calendar' do
    it 'defaults to the first calendar if this google account only has 1' do
      google_integration.calendar_id = nil
      google_integration.stub(:calendars).and_return(calendar_data.items)
      first_calendar = calendar_data.items.first

      google_integration.set_default_calendar

      expect(google_integration.calendar_id).to eq(first_calendar['id'])
      expect(google_integration.calendar_name).to eq(first_calendar['summary'])
    end
  end

  context '#create_new_calendar' do
    let(:calendar_insert_api) { double }
    let(:client) { double(execute: double(data: calendar_data.items.first)) }

    it 'creates a new calendar' do
      google_integration.calendar_id = nil
      google_integration.new_calendar = 'new calendar'

      google_integration.google_account.stub(:client).and_return(client)
      google_integration.stub_chain(:calendar_api, :calendars, :insert).and_return(calendar_insert_api)

      client.should_receive(:execute).with(:api_method => calendar_insert_api,
                                           :body_object => {'summary' => google_integration.new_calendar})

      first_calendar = calendar_data.items.first

      google_integration.create_new_calendar

      expect(google_integration.calendar_id).to eq(first_calendar['id'])
      expect(google_integration.calendar_name).to eq(google_integration.new_calendar)
    end
  end
end
