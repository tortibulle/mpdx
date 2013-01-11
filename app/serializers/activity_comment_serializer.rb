class ActivityCommentSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id, :body, :activity_id, :person_id, :created_at, :updated_at

end
