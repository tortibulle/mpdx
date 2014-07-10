class GoogleEmailActivity < ActiveRecord::Base
  belongs_to :activity
  belongs_to :google_email
end
