rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = YAML.load_file(rails_root + '/config/redis.yml')

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://' + resque_config[rails_env],
                   namespace: "MPDX:#{rails_env}:resque"}
end

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://' + resque_config[rails_env],
                   namespace: "MPDX:#{rails_env}:resque"}
  config.failures_default_mode = :exhausted
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Sidekiq.configure_client do |config|
      config.redis = { :size => 1 }
    end if forked
  end
end
