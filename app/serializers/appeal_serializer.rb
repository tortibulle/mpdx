class AppealSerializer < ActiveModel::Serializer
  embed :ids, include: true
  #has_many :contacts
  ATTRIBUTES = [:id, :name, :amount, :description, :end_date]
  attributes(*ATTRIBUTES)

  attribute :contact_ids, key: :contacts
  attribute :donation_ids, key: :donations
end
