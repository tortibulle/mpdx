class Task < Activity

  before_save :update_completed_at

  assignable_values_for :activity_type, :allow_blank => true do
    [_('Call'), _('Appointment'), _('Email'), _('Text Message'), _('Facebook Message'),
     _('Letter'), _('Newsletter'), _('Pre Call Letter'), _('Reminder Letter'),
     _('Support Letter'), _('Thank'), _('To Do')]
  end

  assignable_values_for :result, :allow_blank => true do
    [_('Attempted'), _('Done')]
  end

  def attempted?
    'Attempted' == result
  end

  private
    def update_completed_at
      if changed.include?('completed')
        self.completed_at = completed? ? Time.now : nil
      end
    end
end
