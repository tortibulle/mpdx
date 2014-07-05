class ActivityComment < ActiveRecord::Base
  has_paper_trail on: [:destroy],
                  meta: { related_object_type: 'Activity',
                          related_object_id: :activity_id }

  belongs_to :activity, counter_cache: true, touch: true
  belongs_to :person

  validates :body, presence: true

  before_create :ensure_person

  private

  def ensure_person
    unless person_id
      self.person = Thread.current[:user]
    end
  end
end
