module AddressMethods
  extend ActiveSupport::Concern

  included do
    has_many :addresses, as: :addressable, dependent: :destroy
    has_one :primary_address, class_name: 'Address', conditions: {primary_mailing_address: true}, as: :addressable

    accepts_nested_attributes_for :addresses, reject_if: :blank_or_duplicate_address?, allow_destroy: true
  end

  def blank_or_duplicate_address?(attributes)
    return false if attributes['id']
    attributes.slice('street', 'city', 'state', 'country', 'postal_code').all? { |_, v| v.blank? } ||
    addresses.where(attributes.slice('street', 'city', 'state', 'country', 'postal_code')).first.present?
  end

  def address
    primary_address || addresses.first
  end

end
