SiebelDonations.configure do |config|
  config.oauth_token = APP_CONFIG['itg_auth_key']
  config.default_timeout = 60000
  config.base_url = 'https://wsapi.ccci.org/wsapi/rest'
end
