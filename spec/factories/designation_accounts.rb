# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :designation_account do
    designation_number "1234567"
    association :organization
  end
end
