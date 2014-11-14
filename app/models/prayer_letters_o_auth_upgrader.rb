class PrayerLettersOAuthUpgrader
  include Sidekiq::Worker
  sidekiq_options retry: false, backtrace: true, unique: true

  def perform
    PrayerLettersAccount.where(oauth2_token: nil).each(&:upgrade_account_to_oauth2)
  end
end
