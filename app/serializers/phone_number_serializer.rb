class PhoneNumberSerializer < ActiveModel::Serializer
  attributes :id, :number, :country_code, :location, :primary, :created_at, :updated_at
end
