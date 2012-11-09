# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :notification_preference do
    notification_type_id 1
    actions "MyText"
  end
end
