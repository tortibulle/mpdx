unless defined?(APP_CONFIG)
  APP_CONFIG = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
end
