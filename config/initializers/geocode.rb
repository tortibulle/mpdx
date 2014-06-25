require Rails.root.join('config','initializers','load_config').to_s
Geocoder.configure(
  #api_key: APP_CONFIG['geocode_key']
)