# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :account_list do
    name "MyString"
    #association :creator, factory: :user
    #association :designation_profile
  end
end
