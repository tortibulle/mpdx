source 'http://rubygems.org'

gem 'rails', '~> 4.0.0'

# Gems used only for assets and not required
# in production environments by default.
gem 'sass-rails',   '~> 4.0.1'
gem 'coffee-rails', '~> 4.0.1'

#gem 'execjs', '~> 1.4.0'
gem 'therubyracer'
#gem 'therubyrhino', '~> 2.0.2'

gem 'uglifier', '~> 2.4.0'
gem 'jquery-ui-rails'#, '~> 3.0.1'

#gem 'activeadmin'
gem 'active_model_serializers' #, git: 'http://github.com/rails-api/active_model_serializers.git'
gem 'acts-as-taggable-on', '~> 3.0.0'
gem 'airbrake'#, '~> 3.1.6'
gem 'assignable_values', '~> 0.5.3'
gem 'carrierwave'
gem 'cloudinary'
gem 'country_select', git: 'http://github.com/CruGlobal/country_select.git' # My fork has the meta data for the fancy select
gem 'dalli'
gem 'deadlock_retry', '~> 1.2.0'
gem 'devise', '~> 3.2.2'
gem 'display_case', '= 0.0.5'
gem 'fb_graph', '~> 2.6.0'
gem 'fog', '~> 1.12.0'
gem 'font-awesome-rails'
gem 'gettext_i18n_rails'#, '~> 1.0.3'
#gem 'gettext_i18n_rails_js'#, '~> 0.0.3'
gem 'gibberish', '~> 1.2.0'
gem 'gibbon', '~> 0.4.2'
gem 'google-api-client'
gem 'google_contacts_api'
gem 'gmail', git: 'http://github.com/90seconds/gmail.git'
gem 'iniparse', '~> 1.1.6'
gem 'jquery-rails', '~> 3.0.4'
gem 'koala', '~> 1.6.0'
gem 'linkedin', '~> 0.3.7'
gem 'newrelic_rpm', '~> 3.6.3'
gem 'oauth', git: 'http://github.com/CruGlobal/oauth-ruby'
gem 'oj', '~> 2.1.0'
gem 'omniauth-cas', '= 1.0.1'
gem 'omniauth-facebook', '~> 1.4.1'
gem 'omniauth-google-oauth2', '~> 0.2.0'
gem 'omniauth-linkedin', '~> 0.0.8'
gem 'omniauth-prayer-letters'
gem 'omniauth-twitter', '~> 0.0.14'
gem 'paper_trail', '~> 3.0.0'
gem 'pg', '~> 0.14.1'
gem 'rails_autolink', '~> 1.1.5'
gem 'rake'
gem 'redis-namespace'
gem 'redis-objects', '~> 0.6.1'
gem 'rest-client', '~> 1.6.7'
gem 'retryable-rb', '~> 1.1.0'
gem 'rollout', '~> 2.0.0'
gem 'ruby-rtf'
gem 'secure_headers'
gem 'sidekiq', '~> 2.17.0'
gem 'sidekiq-failures', git: 'http://github.com/mhfs/sidekiq-failures.git'
gem 'siebel_donations', '~> 1.0.5'
gem 'sinatra', :require => nil
gem 'slim' # used for sidekiq web
gem 'twitter_cldr', '~> 2.4.0'
gem 'typhoeus', '~> 0.6.3'
gem 'versionist', '~> 1.2.1'
gem 'virtus', '~> 0.5.4'
gem 'whenever', '~> 0.8.1'
gem 'wicked', '~> 1.0.2'
gem 'will_paginate', '~> 3.0.3'

gem 'unicorn'

group :development do
  gem 'railroady'
  gem 'rails-footnotes', git: 'http://github.com/josevalim/rails-footnotes.git'
  gem 'bluepill'
end

group :development, :test do
  gem 'awesome_print'
  gem 'database_cleaner'
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem "guard-rspec"
  gem 'simplecov', :require => false
  #only used for mo/po file generation in development, !do not load(:require=>false)! since it will eat 7mb ram
  gem "gettext", '~> 2.3.2', :require => false
  gem 'mailcatcher'
  gem 'fuubar'
end
group :test do
  gem 'webmock', '~> 1.9.0'
  gem 'spork-rails'#, '~> 3.2.0'
  gem 'rb-fsevent', :require => false
  gem 'guard-spork'
  gem 'growl'
  gem 'capybara'
  gem 'resque_spec'
  gem 'emoji_spec', :git => "https://gist.github.com/6112257.git"
end