source 'http://rubygems.org'

gem 'rails', '3.2.3'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  gem 'execjs'
  #gem 'therubyracer', :platforms => :ruby
  gem 'therubyrhino'

  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# the javascript engine for execjs gem
platforms :jruby do
  gem 'activerecord-jdbcmysql-adapter'

  gem 'jruby-openssl'
end

platforms :mri do
  gem 'mysql2'
  group :test do
    gem 'spork-rails', '~> 3.2.0'
    gem 'rb-fsevent', :require => false
    gem 'guard-spork'
    gem 'growl'
  end
end
gem 'resque-ensure-connected'
gem 'devise', '~> 2.0.0'
gem 'dalli'
gem 'twitter_cldr'
gem "gettext_i18n_rails"

gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'omniauth-linkedin'
gem 'omniauth-google-oauth2'
gem 'omniauth-cas', '~> 0.0.6'
gem 'rake'
gem 'newrelic_rpm'
gem 'assignable_values'
gem 'awesome_print'
gem 'koala'
gem 'typhoeus'
gem 'country_select', git: 'git://github.com/26am/country_select.git'
gem 'iniparse'
gem 'versionist'
gem 'rest-client'
gem 'airbrake'
gem 'wicked'
gem 'will_paginate', '~> 3.0'
gem 'resque'
gem 'resque-retry'
gem 'resque-lock'
gem 'deadlock_retry'
gem 'linkedin', git: 'git://github.com/twinge/linkedin.git'
gem 'redis-objects'
gem 'carrierwave', git: 'git://github.com/twinge/carrierwave.git'
gem 'fb_graph'
gem "acts-as-taggable-on", :git => "git://github.com/mbleigh/acts-as-taggable-on.git"
gem "fog", "~> 1.3.1"

group :development do
  gem 'unicorn'
  gem 'rails-footnotes'
end

group :development, :test do
  gem 'database_cleaner'
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem "guard-rspec"
  gem 'simplecov', :require => false
  #only used for mo/po file generation in development, !do not load(:require=>false)! since it will only eat 7mb ram
  gem "gettext", '>= 1.9.3', :require => false
end
group :test do
  gem 'webmock', '= 1.8.3'
end
