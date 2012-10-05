# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :mail_chimp_account do
    api_key "MyString"
    valid false
    primary_list "MyString"
  end
end
