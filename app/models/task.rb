class Task < Activity
  attr_accessible :activity_type

  assignable_values_for :activity_type, :allow_blank => true do
    ['Appointment', 'Call', 'Email', 'Text Message', 'Facebook Message', 'Letter', 'Newsletter',
     'Pre Call Letter', 'Reminder Letter', 'Support Letter', 'Thanks', 'To Do']
  end
end
