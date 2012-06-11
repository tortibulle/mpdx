# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :donor_account do
    association :organization
    account_number "MyString"
    name "MyString"
  end
end
