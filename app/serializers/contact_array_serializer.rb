require 'digest/sha1'

class ContactArraySerializer < ActiveModel::ArraySerializer
  cache

  def cache_key
    Digest::SHA1.hexdigest(object.collect(&:cache_key).join('/'))
   end

  def each_serializer
    ContactSerializer
  end
end
