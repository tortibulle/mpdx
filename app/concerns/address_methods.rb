module AddressMethods
  extend ActiveSupport::Concern

  included do
    has_many :addresses, as: :addressable, conditions: {deleted: false}, order: 'addresses.primary_mailing_address::int desc'
    has_many :addresses_including_deleted, class_name: 'Address', as: :addressable
    has_one :primary_address, class_name: 'Address', conditions: {primary_mailing_address: true, deleted: false}, as: :addressable

    accepts_nested_attributes_for :addresses, reject_if: :blank_or_duplicate_address?, allow_destroy: true

    after_destroy :destroy_addresses
  end

  def blank_or_duplicate_address?(attributes)
    return false if attributes['id']
    attributes.slice('street', 'city', 'state', 'country', 'postal_code').all? { |_, v| v.blank? } ||
    addresses.where(attributes.slice('street', 'city', 'state', 'country', 'postal_code')).first.present?
  end

  def address
    primary_address || addresses.first
  end

  def destroy_addresses
    addresses.map(&:destroy!)
  end

end
