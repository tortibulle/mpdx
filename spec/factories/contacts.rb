# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :contact do
    association :account_list
    name 'John'
  end
end
