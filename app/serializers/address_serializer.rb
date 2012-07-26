class AddressSerializer < ActiveModel::Serializer
  attributes :id, :street, :city, :state, :country, :postal_code, :location, :start_date,
             :end_date, :primary_mailing_address
end
