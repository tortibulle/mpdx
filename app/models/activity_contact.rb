class ActivityContact < ActiveRecord::Base

  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: 'Activity',
                             related_object_id: :activity_id }

  belongs_to :activity
  belongs_to :task, foreign_key: 'activity_id'
  belongs_to :contact

  # attr_accessible :contact_id, :activity_id
end
