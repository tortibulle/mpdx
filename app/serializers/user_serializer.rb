require 'digest/sha1'

class UserSerializer < ActiveModel::Serializer
  # cached

  embed :ids, include: true
  attributes :id, :first_name, :last_name, :master_person_id, :preferences, :created_at, :updated_at

  has_many :account_lists

  # def cache_key
  #   Digest::SHA1.hexdigest(([object.cache_key] + object.account_lists.collect(&:cache_key) + object.designation_accounts.collect(&:cache_key)).join('/'))
  # end
end
