require 'sidekiq/pro/reliable_push'

rails_root = ENV['RAILS_ROOT'] || Rails.root.to_s
rails_env = ENV['RAILS_ENV'] || 'development'

redis_config = YAML.load_file(rails_root + '/config/redis.yml')

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://' + redis_config[rails_env],
                   namespace: "MPDX:#{rails_env}:resque"}
end

Sidekiq.configure_server do |config|
  require 'sidekiq/pro/reliable_fetch'
  config.redis = { url: 'redis://' + redis_config[rails_env],
                   namespace: "MPDX:#{rails_env}:resque"}
end

