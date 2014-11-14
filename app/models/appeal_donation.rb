class AppealDonation < ActiveRecord::Base
  has_paper_trail on: [:destroy],
                  meta: { related_object_type: 'Appeal',
                          related_object_id: :appeal_id }

  belongs_to :appeal, foreign_key: 'appeal_id'
  belongs_to :donation
end
