require Rails.root.join('config', 'initializers', 'redis').to_s
$rollout = Rollout.new(Redis.current)

$rollout.define_group(:testers) do |account_list|
  account_list.tester == true
end
