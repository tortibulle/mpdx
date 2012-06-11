require Rails.root.join('config','initializers','load_config').to_s
LINKEDIN = LinkedIn::Client.new(APP_CONFIG['linkedin_key'], APP_CONFIG['linkedin_secret'])
