source 'http://rubygems.org'

gem 'rails', '~> 3.2.3'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  gem 'execjs'
  #gem 'therubyracer', :platforms => :ruby
  gem 'therubyrhino'

  gem 'uglifier', '>= 1.0.3'
  gem 'jquery-ui-rails'
end

gem 'jquery-rails'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# the javascript engine for execjs gem
#platforms :jruby do
  #gem 'activerecord-jdbcmysql-adapter'

  #gem 'jruby-openssl'
#end

platforms :mri do
  #gem 'mysql2'
  gem 'pg'
end
gem 'resque-ensure-connected'
gem 'devise', '~> 2.1.0'
gem 'dalli'
gem 'twitter_cldr', '~> 1.8.0'
gem "gettext_i18n_rails"
gem 'gettext_i18n_rails_js'#, path: '/Users/josh/htdocs/gettext_i18n_rails_js' #,git: 'git://github.com/twinge/gettext_i18n_rails_js.git'

gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'omniauth-linkedin'
gem 'omniauth-google-oauth2'
gem 'omniauth-cas', '~> 0.0.6'
gem 'rake'
gem 'newrelic_rpm'
gem 'assignable_values'
gem 'charlock_holmes'
gem 'awesome_print'
gem 'koala'
gem 'typhoeus'
gem 'country_select', git: 'git://github.com/26am/country_select.git' # My fork has the meta data for the fancy select
gem 'iniparse'
gem 'versionist', git: 'git://github.com/twinge/versionist.git', branch: 'multiple_versioning_strategies' # Switch back to gem once multiple_strategies are supported
gem 'rest-client'
gem 'airbrake'
gem 'wicked'
gem 'will_paginate', '~> 3.0'
gem 'resque'
gem 'resque-retry'
gem 'resque-lock'
gem 'deadlock_retry'
gem 'linkedin'
gem 'redis-objects'
gem 'carrierwave', git: 'git://github.com/jnicklas/carrierwave.git' # tracking master because of fixes made since last gem version
gem 'fb_graph'
gem "acts-as-taggable-on", '~> 2.3.3'
gem "fog", "~> 1.6.0"
gem 'gibberish'
gem 'active_model_serializers', git: 'git://github.com/josevalim/active_model_serializers.git'
gem 'rails_autolink'
gem 'display_case'
gem 'gibbon'

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
  #only used for mo/po file generation in development, !do not load(:require=>false)! since it will eat 7mb ram
  gem "gettext", '~> 2.3.2', :require => false
  gem 'mailcatcher'
end
group :test do
  gem 'webmock', '~> 1.8.3'
  gem 'spork-rails', '~> 3.2.0'
  gem 'rb-fsevent', :require => false
  gem 'guard-spork'
  gem 'growl'
  gem 'capybara'
end
