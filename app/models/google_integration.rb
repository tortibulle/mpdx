require 'async'
class GoogleIntegration < ActiveRecord::Base
  include Async
  include Sidekiq::Worker
  sidekiq_options backtrace: true, unique: true

  belongs_to :google_account, class_name: 'Person::GoogleAccount', inverse_of: :google_integrations, dependent: :destroy
  belongs_to :account_list, inverse_of: :google_integrations

  attr_accessor :new_calendar

  serialize :calendar_integrations, Set

  before_save :create_new_calendar, if: -> { new_calendar.present? }
  before_save :toggle_calendar_integration_for_appointments, :set_default_calendar, if: :calendar_integration_changed?


  def queue_sync_data(integration = nil)
    async(:sync_data, integration) if integration
  end

  def sync_data(integration)
    case integration
    when 'calendar'
      calendar_integrator.sync_tasks
    end
  end

  def calendar_integrator
    @calendar_integrator ||= GoogleCalendarIntegrator.new(self)
  end

  def plus_api
    @plus_api ||= google_account.client.discovered_api('plus')
  end

  def calendar_api
    @calendar_api ||= google_account.client.discovered_api('calendar', 'v3')
  end

  def calendars
    unless @calendars
      result = google_account.client.execute(
        :api_method => calendar_api.calendar_list.list,
        :parameters => {'userId' => 'me'}
      )
      calendar_list = result.data
      @calendars = calendar_list.items.select {|c| c.accessRole == 'owner'}
    end
    @calendars
  end

  def toggle_calendar_integration_for_appointments
    if calendar_integration?
      calendar_integrations << 'Appointment'
    else
      calendar_integrations.delete('Appointment')
    end
  end

  def set_default_calendar
    if calendar_integration? && calendar_id.blank? && calendars.length == 1
      calendar = calendars.first
      self.calendar_id = calendar['id']
      self.calendar_name = calendar['summary']
    end
  end

  def create_new_calendar
    result = google_account.client.execute(
      :api_method => calendar_api.calendars.insert,
      :body_object => {'summary' => new_calendar}
    )
    Rails.logger.debug(result)
    self.calendar_id = result.data['id']
    self.calendar_name = new_calendar
  end
end
