# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_event do
    activity nil
    google_integration nil
    google_event_id "MyString"
  end
end
