class Task < Activity
  attr_accessible :activity_type

  before_save :update_completed_at

  assignable_values_for :activity_type, :allow_blank => true do
    ['Call', 'Appointment', 'Email', 'Text Message', 'Facebook Message', 'Letter', 'Newsletter',
     'Pre Call Letter', 'Reminder Letter', 'Support Letter', 'Thanks', 'To Do']
  end

  assignable_values_for :result, :allow_blank => true do
    ['Attempted', 'Done']
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
