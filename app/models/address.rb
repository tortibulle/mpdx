class Address < ActiveRecord::Base

  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: :addressable_type,
                             related_object_id: :addressable_id }

  belongs_to :addressable, polymorphic: true, touch: true

  assignable_values_for :location, :allow_blank => true do
    [_('Home'), _('Business'), _('Mailing'), _('Other')]
  end

  def ==(other)
    if other
      other.street == street &&
      other.city == city &&
      other.state == state &&
      other.country == country &&
      other.postal_code.to_s[0..4] == postal_code.to_s[0..4]
    else
      false
    end
  end

  def not_blank?
    attributes.with_indifferent_access.slice(:street, :city, :state, :country, :postal_code).any? { |_, v| v.present? && v.strip != '(UNDELIVERABLE)' }
  end

  def merge(other_address)
    self.primary_mailing_address = (primary_mailing_address? || other_address.primary_mailing_address?)
    self.seasonal = (seasonal? || other_address.seasonal?)
    self.location = other_address.location if location.blank?
    self.save(validate: false)
    other_address.destroy
  end

end
