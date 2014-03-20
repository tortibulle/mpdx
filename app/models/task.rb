class Task < Activity

  before_validation :update_completed_at
  after_save :update_contact_uncompleted_tasks_count
  after_destroy :update_contact_uncompleted_tasks_count

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

  CALL_RESULTS = [_('Attempted')]
  MESSAGE_RESULTS = [_('Received')]
  STANDARD_RESULTS = [_('Done')]
  ALL_RESULTS = STANDARD_RESULTS + CALL_RESULTS + MESSAGE_RESULTS

  assignable_values_for :activity_type, :allow_blank => true do
    [_('Call'), _('Appointment'), _('Email'), _('Text Message'), _('Facebook Message'),
     _('Letter'), _('Newsletter'), _('Pre Call Letter'), _('Reminder Letter'),
     _('Support Letter'), _('Thank'), _('To Do')]
  end

  assignable_values_for :result, :allow_blank => true do
    case activity_type
      when 'Call'
        CALL_RESULTS + STANDARD_RESULTS
      when 'Email', 'Text Message', 'Facebook Message', 'Letter'
        STANDARD_RESULTS + MESSAGE_RESULTS
      else
        STANDARD_RESULTS
    end
  end

  def attempted?
    'Attempted' == result
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
end
