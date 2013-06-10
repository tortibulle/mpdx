class PhoneNumberSerializer < ActiveModel::Serializer
  embed :ids, include: true
  ATTRIBUTES = [:id, :number, :country_code, :location, :primary, :created_at, :updated_at]
  attributes *ATTRIBUTES

end
