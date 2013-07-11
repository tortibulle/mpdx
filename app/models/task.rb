class Task < Activity

  before_validation :update_completed_at
  after_save :update_contact_uncompleted_tasks_count

  scope :of_type, ->(activity_type) { where(activity_type: activity_type) }
  scope :with_result, ->(result) { where(result: result) }
  scope :completed_between, -> (start_date, end_date) { where("completed_at BETWEEN ? and ?", start_date, end_date) }
  scope :created_between, -> (start_date, end_date) { where("created_at BETWEEN ? and ?", start_date, end_date) }

  assignable_values_for :activity_type, :allow_blank => true do
    [_('Call'), _('Appointment'), _('Email'), _('Text Message'), _('Facebook Message'),
     _('Letter'), _('Newsletter'), _('Pre Call Letter'), _('Reminder Letter'),
     _('Support Letter'), _('Thank'), _('To Do')]
  end

  assignable_values_for :result, :allow_blank => true do
    [_('Attempted'), _('Received'), _('Done')]
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
      contacts.map(&:update_uncompleted_tasks_count) if completed
    end
end
