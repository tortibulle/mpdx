# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :email_address do
    sequence(:email) { |n| "foo#{n}@example.com" }
    primary false
  end
end
