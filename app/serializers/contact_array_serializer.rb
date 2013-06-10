require 'digest/sha1'

class ContactArraySerializer < ActiveModel::ArraySerializer
  cache

  def cache_key
    scope = options[:scope] || {}
    Digest::SHA1.hexdigest((object.collect(&:cache_key) + ['include', scope[:include]]).join(','))
   end

  def each_serializer
    ContactSerializer
  end
end
