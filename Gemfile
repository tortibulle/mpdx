source 'http://rubygems.org'

gem 'rails', '~> 3.2.3'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  gem 'execjs', '~> 1.4.0'
  #gem 'therubyracer', :platforms => :ruby
  gem 'therubyrhino', '~> 2.0.2'

  gem 'uglifier', '~> 1.3.0'
  gem 'jquery-ui-rails', '~> 3.0.0'
end

gem 'activeadmin'
gem 'active_model_serializers', git: 'git://github.com/rails-api/active_model_serializers.git'
gem 'acts-as-taggable-on', '~> 2.3.3'
gem 'airbrake', '~> 3.1.6'
gem 'airbrake_user_attributes', '~> 0.1.6'
gem 'assignable_values', '~> 0.5.3'
gem 'carrierwave', git: 'git://github.com/jnicklas/carrierwave.git' # tracking master because of fixes made since last gem version
gem 'country_select', git: 'git://github.com/26am/country_select.git' # My fork has the meta data for the fancy select
gem 'dalli'
gem 'deadlock_retry', '~> 1.2.0'
gem 'devise', '~> 2.1.0'
gem 'display_case', '~> 0.0.5'
gem 'fb_graph', '~> 2.6.0'
gem 'fog', '~> 1.6.0'
gem 'gettext_i18n_rails', '~> 0.8.0'
gem 'gettext_i18n_rails_js', '~> 0.0.3'
gem 'gibberish', '~> 1.2.0'
gem 'gibbon', '~> 0.4.2'
gem 'iniparse', '~> 1.1.6'
gem 'jquery-rails', '~> 2.1.4'
gem 'koala', '~> 1.6.0'
gem 'linkedin', '~> 0.3.7'
gem 'newrelic_rpm', '~> 3.5.4'
gem 'oj', '~> 2.0.0'
gem 'omniauth-cas', '~> 1.0.0'
gem 'omniauth-facebook', '~> 1.4.1'
gem 'omniauth-google-oauth2', '~> 0.1.13'
gem 'omniauth-linkedin', '~> 0.0.8'
gem 'omniauth-twitter', '~> 0.0.14'
gem 'paper_trail', '~> 2.7.0'
gem 'pg', '~> 0.14.1'
gem 'rails_autolink', '~> 1.0.9'
gem 'rake'
gem 'redis-objects', '~> 0.6.1'
gem 'rest-client', '~> 1.6.7'
gem 'retryable-rb', '~> 1.1.0'
gem 'secure-headers', require: 'secure_headers'
gem 'sidekiq'
gem 'sidekiq-failures'
gem 'siebel_donations', git: 'git://github.com/twinge/siebel_donations.git'
gem 'sinatra', :require => nil
gem 'slim'
gem 'twitter_cldr', '~> 2.0.0'
gem 'typhoeus', '~> 0.5.3'
gem 'versionist'
gem 'virtus', '~> 0.5.4'
gem 'whenever', '~> 0.8.1'
gem 'wicked', '~> 0.3.4'
gem 'will_paginate', '~> 3.0.3'

group :development do
  gem 'railroady'
  gem 'unicorn'
  gem 'rails-footnotes'
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
  gem 'spork-rails', '~> 3.2.0'
  gem 'rb-fsevent', :require => false
  gem 'guard-spork'
  gem 'growl'
  gem 'capybara'
  gem 'resque_spec'
  gem 'fuubar'
end

# RAILS 4 -- should be able to remove these after upgrading
gem 'cache_digests'

group :development do
  gem 'quiet_assets'
end
