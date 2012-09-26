class Task < Activity
  attr_accessible :activity_type

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
end
