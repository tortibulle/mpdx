require 'cgi'

module SmartyStreets
  def self.auth_id
    APP_CONFIG['smarty_auth_id']
  end

  def self.auth_token
    APP_CONFIG['smarty_auth_token']
  end

  def self.get(address_hash)
    zipcode = address_hash[:postal_code] || address_hash[:zipcode]

    unless address_hash[:street].present? &&
           (zipcode ||
             (address_hash[:city] && address_hash[:state]))
      return []
    end
    url = 'https://api.smartystreets.com/street-address/?'
    params = []

    parts = address_hash[:street].strip.split("\n").compact
    street1 = parts.first
    street2 = parts[1]

    params << "street=#{CGI.escape(street1)}" if street1.present?
    params << "street2=#{CGI.escape(street2.gsub(/[><']/, ''))}" if street2.present?
    params << "city=#{CGI.escape(address_hash[:city])}" if address_hash[:city].present?
    params << "state=#{CGI.escape(address_hash[:state])}" if address_hash[:state].present?
    params << "zipcode=#{CGI.escape(zipcode)}" if zipcode.present?
    params << "candidates=2&auth-id=#{auth_id}&auth-token=#{auth_token}"

    url += params.join('&')

    response = RestClient.get(url, content_type: :json, accept: :json)

    JSON.parse(response)
  end
end
