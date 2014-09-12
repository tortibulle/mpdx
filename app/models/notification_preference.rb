class NotificationPreference < ActiveRecord::Base
  belongs_to :account_list
  belongs_to :notification_type

  serialize :actions
  # attr_accessible :actions, :notification_type_id
  validates :actions, :notification_type_id, presence: true

  def self.default_actions
    %w(email task)
  end
end
