class GoogleEvent < ActiveRecord::Base
  belongs_to :activity
  belongs_to :google_integration
end
