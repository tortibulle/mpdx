class AppealSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attribute :contact_ids, key: :contacts

  private
end
