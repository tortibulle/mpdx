# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :mail_chimp_account do
    api_key "MyString"
    active false
    primary_list_id "MyString"
  end
end
