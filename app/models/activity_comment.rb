class ActivityComment < ActiveRecord::Base
  belongs_to :activity, counter_cache: true
  belongs_to :person

  validates :body, presence: true

  attr_accessible :body
end
