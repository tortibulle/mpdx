class AppealSerializer < ActiveModel::Serializer
  embed :ids, include: true
  #has_many :contacts
  ATTRIBUTES = [:id, :name, :amount, :description, :end_date]
  attributes(*ATTRIBUTES)

  attribute :contact_ids, key: :contacts
  attribute :donations, key: :donations

  def contact_ids
    object.contacts.order(:name).pluck(:id)
  end
end
