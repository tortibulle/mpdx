class Person::FacebookAccountSerializer < ActiveModel::Serializer
  attributes :id, :remote_id
end