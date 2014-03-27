class AddressExhibit < DisplayCase::Exhibit

  def self.applicable_to?(object)
    object.class.name == 'Address'
  end

  def to_s() to_google; end

  def to_html
    case country
    when 'United States', nil, '', 'USA', 'United States of America'
      [street ? street.gsub(/\n/,'<br />') : nil, [[city, state].select(&:present?).join(', '), postal_code].select(&:present?).join(' ')].select(&:present?).join('<br />').html_safe
    else
      to_google
    end
  end

  def to_google
    [street, city, state, postal_code, country].select(&:present?).join(', ')
  end
end

