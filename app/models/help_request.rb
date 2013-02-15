class HelpRequest < ActiveRecord::Base
  mount_uploader :file, HelpRequestUploader

  after_commit :send_email

  belongs_to :account_list
  belongs_to :user

  serialize :session, JSON
  serialize :user_preferences, JSON
  serialize :account_list_preferences, JSON

  validates :name, :email, :problem, presence: true
  validates :email, email: true

  def send_email
    HelpRequestMailer.email(self).deliver
  end
end
