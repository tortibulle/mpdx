class AccountListSerializer < ActiveModel::Serializer
  embed :ids, include: true
  attributes :id, :name, :created_at, :updated_at

  has_many :designation_accounts
end
