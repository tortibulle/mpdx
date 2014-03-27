class PhoneNumberExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'PhoneNumber'
  end

  def to_s() [number, location].join(' - '); end

  def number
    return nil unless self[:number]
    global = GlobalPhone.parse(self[:number])
    if country_code == '1' || (country_code.blank? && (self[:number].length == 10 || self[:number].length == 7))
      global.national_format
    else
      global.international_format
    end

  end

end
