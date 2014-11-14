# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :prayer_letters_account do
    token 'MyString'
    secret 'MyString'
    valid_token true
    association :account_list
  end

  factory :prayer_letters_account_oauth2, class: PrayerLettersAccount do
    oauth2_token 'test_oauth2_token'
    valid_token true
    association :account_list
  end
end
