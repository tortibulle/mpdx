class AccountListSerializer < ActiveModel::Serializer
  cached
  delegate :cache_key, to: :object

  embed :ids, include: true
  attributes :id, :name, :created_at, :updated_at, :monthly_goal, :total_pledges

  has_many :designation_accounts
end
