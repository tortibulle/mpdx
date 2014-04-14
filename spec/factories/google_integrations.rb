# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_integration do
    calendar_integration true
    calendar_id 'asdf'
    association :account_list
    association :google_account
  end
end
