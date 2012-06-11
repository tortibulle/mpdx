#require 'resque-retry'
#require 'resque/failure/redis'

#Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
#Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = YAML.load_file(rails_root + '/config/redis.yml')
Resque.redis = resque_config[rails_env]

Resque.redis.namespace = "MPDX:#{rails_env}:resque"
