class PhoneNumberExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'PhoneNumber'
  end

  def to_s() [number, location].join(' - '); end

  def number
    return nil unless self[:number]
    if country_code == '1' || (country_code.blank? && (self[:number].length == 10 || self[:number].length == 7))
      @context.number_to_phone(self[:number], area_code: self[:number].length == 10)
    else
      self[:number]
    end

  end

end
