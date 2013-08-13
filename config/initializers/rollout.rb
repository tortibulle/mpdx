require Rails.root.join('config', 'initializers', 'redis').to_s
$rollout = Rollout.new(Redis.current)

$rollout.define_group(:testers) do |user|
  user.tester == true
end
