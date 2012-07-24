class UserSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id, :first_name, :last_name, :master_person_id, :created_at, :updated_at

  has_many :account_lists
end
