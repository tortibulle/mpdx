class AppealSerializer < ActiveModel::Serializer
  embed :ids, include: true
  #has_many :contacts
  ATTRIBUTES = [:name, :amount, :description, :end_date, :contact_ids]

  attributes(*ATTRIBUTES)
end
