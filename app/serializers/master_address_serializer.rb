class MasterAddressSerializer < ActiveModel::Serializer
  attributes :id, :street, :city, :state, :country, :postal_code
end
