class MailChimpAccountSerializer < ActiveModel::Serializer
  attributes :id, :api_key, :valid, :primary_list
end
