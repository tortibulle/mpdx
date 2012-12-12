class ActivityContact < ActiveRecord::Base
  belongs_to :activity
  belongs_to :contact

  # attr_accessible :contact_id, :activity_id
end
