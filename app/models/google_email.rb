class GoogleEmail < ActiveRecord::Base
  has_many :google_email_activities, dependent: :destroy
  has_many :activities, through: :google_email_activities
  belongs_to :google_account
end
