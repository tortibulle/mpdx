# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_event do
    association :activity
    association :google_integration
    google_event_id 'MyString'
  end
end
