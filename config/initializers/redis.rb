require 'redis'
require 'redis/objects'
rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
#if rails_env == 'test'
  #Redis.current = Redis.new(host: 'localhost', port: 9736)
#else
  resque_config = YAML.load_file(rails_root + '/config/redis.yml')
  host, port = resque_config[rails_env].split(':')
  Redis.current = Redis::Namespace.new("MPDX:#{rails_env}", redis: Redis.new(host: host, port: port))
#end
