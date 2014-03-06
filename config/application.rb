require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(PhusionPassenger)
  require 'phusion_passenger/rack/out_of_band_gc'
  require 'phusion_passenger/public_api'
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Mpdx
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/app/concerns #{config.root}/app/roles #{config.root}/app/validators #{config.root}/app/errors)

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    if File.exist?(Rails.root.join('config','memcached.yml'))
      cache_server = YAML.load_file(Rails.root.join('config','memcached.yml'))[Rails.env]['host']
    else
      cache_server = 'localhost'
    end
    config.cache_store = :dalli_store, cache_server, { :namespace => 'mpdx', :expires_in => 1.day, :compress => true }
    config.assets.paths << "#{Rails.root}/app/assets/fonts"

    #config.log_tags = [ :uuid, :remote_ip ]

    config.active_record.disable_implicit_join_references = true

    config.exceptions_app = self.routes
  end
end

