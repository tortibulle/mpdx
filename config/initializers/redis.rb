require 'redis'
require 'redis/objects'
require 'redis/namespace'
rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = YAML.load_file(rails_root + '/config/redis.yml')
host, port = resque_config[rails_env].split(':')
Redis.current = Redis::Namespace.new("MPDX:#{rails_env}", redis: Redis.new(host: host, port: port))
