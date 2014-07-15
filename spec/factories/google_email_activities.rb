# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_email_activity do
    association :google_email
    association :activity
  end
end
