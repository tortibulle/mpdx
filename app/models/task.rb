require 'async'
class Task < Activity
  include Async
  include Sidekiq::Worker
  sidekiq_options backtrace: true, unique: true

  before_validation :update_completed_at
  after_save :update_contact_uncompleted_tasks_count, :sync_to_google_calendar
  after_destroy :update_contact_uncompleted_tasks_count, :sync_to_google_calendar

  scope :of_type, ->(activity_type) { where(activity_type: activity_type) }
  scope :with_result, ->(result) { where(result: result) }
  scope :completed_between, -> (start_date, end_date) { where("completed_at BETWEEN ? and ?", start_date.in_time_zone, (end_date + 1.day).in_time_zone) }
  scope :created_between, -> (start_date, end_date) { where("created_at BETWEEN ? and ?", start_date.in_time_zone, (end_date + 1.day).in_time_zone) }

  PERMITTED_ATTRIBUTES = [
    :starred, :location, :subject, :start_at, :end_at, :activity_type, :result, :completed_at,
    :completed,
    :tag_list, {
      activity_comments_attributes: [:body],
      activity_comment: [:body],
      activity_contacts_attributes: [:contact_id, :_destroy]
    }
  ]

  # validates :activity_type, :presence => { :message => _( '/ Action is required') }

  CALL_RESULTS = ['Done', 'Attempted - Left Message', 'Attempted - Call Again', 'Complete - Call Again', 'Complete - Appointment Scheduled', 'Complete - Partner - Financial', 'Complete - Partner - Special', 'Complete - Partner - Pray', 'Complete - Ask in Future', 'Complete - Not Interested', 'Received - Call Again', 'Received - Appointment Scheduled', 'Received - Partner - Financial', 'Received - Partner - Special', 'Received - Partner - Pray', 'Received - Ask in Future', 'Received - Not Interested']
  MESSAGE_RESULTS = [_('Received')]
  STANDARD_RESULTS = [_('Done')]
  APPOINTMENT_RESULTS = ['Done', 'Decision Received', 'Call for Decision', 'Partner - Financial', 'Attempted - Reschedule']
  ALL_RESULTS = STANDARD_RESULTS + CALL_RESULTS + MESSAGE_RESULTS

  assignable_values_for :activity_type, :allow_blank => true do
    ['Call', 'Appointment', 'Email', 'Text Message', 'Facebook Message',
     'Letter', 'Newsletter', 'Pre Call Letter', 'Reminder Letter',
     'Support Letter', 'Thank', 'To Do']
  end

  assignable_values_for :result, :allow_blank => true do
    case activity_type
      when 'Call'
        CALL_RESULTS + STANDARD_RESULTS
      when 'Email', 'Text Message', 'Facebook Message', 'Letter'
        STANDARD_RESULTS + MESSAGE_RESULTS
      when 'Appointment'
        APPOINTMENT_RESULTS
      else
        STANDARD_RESULTS
    end
  end

  def attempted?
    'Attempted' == result
  end

  def default_length
    case activity_type
    when 'Appointment'
      1.hour
    when 'Call'
      5.minutes
    end
  end

  def calculated_location
    return location if location.present?

    case activity_type
    when 'Call'
      numbers = contacts.collect(&:people).flatten.collect do |person|
        if person.phone_number && person.phone_number.present?
          "#{person} #{PhoneNumberExhibit.new(person.phone_number, nil)}"
        end
      end
      numbers.compact.join("\n")
    else
      return AddressExhibit.new(contacts.first.address, nil).to_google if contacts.first && contacts.first.address
    end
  end

  private
  def update_completed_at
    if changed.include?('completed')
      self.completed_at ||= completed? ? Time.now : nil
      self.start_at ||= completed_at
      self.result = 'Done' if result.blank?
    end
  end

  def update_contact_uncompleted_tasks_count
    contacts.map(&:update_uncompleted_tasks_count)
  end

  def sync_to_google_calendar
    account_list.google_integrations.each do |google_integration|
      google_integration.async(:sync_task, id)
    end
  end
end
