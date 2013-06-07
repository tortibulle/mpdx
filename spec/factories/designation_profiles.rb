# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :designation_profile do
    remote_id 1
    name 'foo'
    association :organization
    association :user
    #association :account_list
  end
end
