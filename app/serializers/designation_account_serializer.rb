class DesignationAccountSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id, :designation_number, :balance, :name, :created_at, :updated_at

end
