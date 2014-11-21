require 'spec_helper'

describe PrayerLettersOAuthUpgrader do
  it 'queries prayer letters accounts without oauth2 tokens and upgrades them' do
    create(:prayer_letters_account)
    create(:prayer_letters_account_oauth2)

    expect_any_instance_of(PrayerLettersAccount).to receive(:upgrade_to_oauth2).exactly(:once)

    PrayerLettersOAuthUpgrader.new.perform
  end
end
