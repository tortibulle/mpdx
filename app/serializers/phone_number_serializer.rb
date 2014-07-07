class PhoneNumberSerializer < ActiveModel::Serializer
  include DisplayCase::ExhibitsHelper

  embed :ids, include: true
  ATTRIBUTES = [:id, :number, :country_code, :location, :primary, :created_at, :updated_at]
  attributes(*ATTRIBUTES)

  def number
    phone_number_exhibit = exhibit(object)
    phone_number_exhibit.number
  end
end
