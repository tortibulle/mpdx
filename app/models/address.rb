require 'smarty_streets'

class Address < ActiveRecord::Base

  US_STATES = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "PR", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: :addressable_type,
                             related_object_id: :addressable_id }

  belongs_to :addressable, polymorphic: true, touch: true
  belongs_to :master_address

  before_create :find_or_create_master_address
  before_update :update_or_create_master_address
  after_destroy :clean_up_master_address


  assignable_values_for :location, :allow_blank => true do
    [_('Home'), _('Business'), _('Mailing'), _('Other')]
  end

  def ==(other)
    if other
      return true if other.master_address_id == self.master_address_id

      return true if other.street.to_s.downcase == street.to_s.downcase &&
                     other.city.to_s.downcase == city.to_s.downcase &&
                     other.state.to_s.downcase == state.to_s.downcase &&
                     (other.country.to_s.downcase == country.to_s.downcase || country.blank? || other.country.blank?) &&
                     other.postal_code.to_s[0..4].downcase == postal_code.to_s[0..4].downcase
    end

    false
  end

  def not_blank?
    attributes.with_indifferent_access.slice(:street, :city, :state, :country, :postal_code).any? { |_, v| v.present? && v.strip != '(UNDELIVERABLE)' }
  end

  def merge(other_address)
    self.primary_mailing_address = (primary_mailing_address? || other_address.primary_mailing_address?)
    self.seasonal = (seasonal? || other_address.seasonal?)
    self.location = other_address.location if location.blank?
    self.remote_id = other_address.remote_id if remote_id.blank?
    self.save(validate: false)
    other_address.destroy
  end

  def country=(val)
    if val.blank?
      self[:country] = val
      return
    end

    countries = ActionView::Helpers::FormOptionsHelper::COUNTRIES
    if country = countries.detect {|c| c[:name].downcase == val.downcase}
      self[:country] = country[:name]
    else
      countries.each do |c|
        if c[:alternatives].downcase.include?(val.downcase)
          self[:country] = c[:name]
          return
        end
      end
      # If we couldn't find a match anywhere, go ahead and save it anyway
      self[:country] = val
    end
  end

  private

  def find_or_create_master_address
    unless master_address_id
      master_address = find_master_address

      unless master_address
        master_address = MasterAddress.create(attributes_for_master_address)
      end

      self.master_address_id = master_address.id
      self.verified = master_address.verified
    end

    true
  end

  def update_or_create_master_address
    new_master_address_match = find_master_address

    unless self.master_address == new_master_address_match
      unless new_master_address_match
        new_master_address_match = MasterAddress.create(attributes_for_master_address)
      end

      self.master_address_id = new_master_address_match.id
      self.verified = new_master_address_match.verified
    end

    true
  end

  def clean_up_master_address

    master_address.destroy if master_address && (master_address.addresses - [self]).blank?

    true
  end

  def find_master_address
    master_address = MasterAddress.where(attributes_for_master_address).first

    # See if another address in the database matches this one and has a master address
    where_clause = attributes_for_master_address.collect {|k, v| "lower(#{k}) = :#{k}" }.join(' AND ')

    master_address ||= Address.where(where_clause, attributes_for_master_address)
                              .where("master_address_id is not null")
                              .first.try(:master_address)

    if !master_address &&
       (attributes_for_master_address[:state].to_s.length == 2 ||
        attributes_for_master_address[:postal_code].to_s.length == 5 ||
        attributes_for_master_address[:postal_code].to_s.length == 10) &&
       (attributes_for_master_address[:country].downcase == 'united states' ||
        (attributes_for_master_address[:country].blank? && US_STATES.include?(attributes_for_master_address[:state].upcase)))

      results = SmartyStreets.get(attributes_for_master_address)
      if results.length == 1
        ss_address = results.first['components']
        attributes_for_master_address[:street] = results.first['delivery_line_1'].downcase
        attributes_for_master_address[:city] = ss_address['city_name'].downcase
        attributes_for_master_address[:state] = ss_address['state_abbreviation'].downcase
        attributes_for_master_address[:postal_code] = [ss_address['zipcode'], ss_address['plus4_code']].compact.join('-').downcase
        attributes_for_master_address[:state] = ss_address['state_abbreviation'].downcase
        attributes_for_master_address[:country] = 'united states'
        attributes_for_master_address[:verified] = true
        master_address = MasterAddress.where(attributes_for_master_address.symbolize_keys
                                                                          .slice(:street, :city, :state, :country, :postal_code))
                                      .first
      end
      attributes_for_master_address[:smarty_response] = results
    end


    master_address
  end

  def attributes_for_master_address
    @attributes_for_master_address ||= Hash[attributes.symbolize_keys
                                                      .slice(:street, :city, :state, :country, :postal_code)
                                                      .select {|k, v| v.present?}
                                                      .map {|k, v| [k, v.downcase] }]
  end

end
