# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :notification_preference do
    association :notification_type
    association :account_list
    actions ['email']
  end
end
