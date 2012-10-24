# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :notification do
    contact nil
    notification_type nil
    event_date "2012-10-23 17:03:15"
  end
end
