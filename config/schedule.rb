# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

if @environment == 'production'
  set :output, '/tmp/sync.log'

  job_type :rake,    "cd :path && PATH=/usr/local/bin:$PATH RAILS_ENV=:environment /usr/local/bin/bundle exec rake :task --silent :output"
  job_type :rails,    "cd :path && PATH=/usr/local/bin:$PATH RAILS_ENV=:environment /usr/local/bin/bundle exec rails :task --silent :output"
  job_type :runner,    "cd :path && PATH=/usr/local/bin:$PATH RAILS_ENV=:environment /usr/local/bin/bundle exec rails runner :task --silent :output"

  every :day, at: '3am' do
    runner "GoogleIntegration.sync_all_email_accounts"
    end

  every :day, at: '5am' do
    runner "AccountList.update_linked_org_accounts"
  end

  every :day, at: '10am' do
    rake 'organizations:fetch'
    rake 'mpdx:clear_stalled_downloads'
    rake 'mailchimp:sync'
  end

  every :day, at: '11am' do
    runner "Person::FacebookAccount.refresh_tokens"
  end
end
# Learn more: http://github.com/javan/whenever
