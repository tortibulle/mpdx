class Address < ActiveRecord::Base
  belongs_to :addressable, polymorphic: true

  assignable_values_for :location, :allow_blank => true do
    [_('Home'), _('Business'), _('Mailing'), _('Other')]
  end

  def ==(other)
    other.street == street &&
    other.city == city &&
    other.state == state &&
    other.country == country &&
    other.postal_code.to_s[0..4] == postal_code.to_s[0..4]
  end

  def not_blank?
    attributes.with_indifferent_access.slice(:street, :city, :state, :country, :postal_code).any? { |_, v| v.present? && v.strip != '(UNDELIVERABLE)' }
  end


end
