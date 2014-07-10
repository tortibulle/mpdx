# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_email do
    google_email_id 1
    association :google_account
  end
end
