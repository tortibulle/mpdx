class Address < ActiveRecord::Base
  belongs_to :addressable, polymorphic: true

  assignable_values_for :location, :allow_blank => true do
    [_('Home'), _('Business'), _('Mailing'), _('Other')]
  end

  attr_accessible :street, :city, :state, :country, :postal_code, :location, :primary_mailing_address, :location, :start_date, :end_date

  def ==(other)
    other.street == street &&
    other.city == city &&
    other.state == state &&
    other.country == country &&
    other.postal_code == postal_code
  end

  def not_blank?
    attributes.with_indifferent_access.slice(:street, :city, :state, :country, :postal_code).any? { |_, v| v.present? && v.strip != '(UNDELIVERABLE)' }
  end


end
