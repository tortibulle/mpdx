# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :import do
    association :account_list
    source "MyString"
    file "MyString"
    importing false
  end
end
