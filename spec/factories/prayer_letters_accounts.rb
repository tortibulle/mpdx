# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :prayer_letters_account do
    token "MyString"
    secret "MyString"
    valid_token true
    association :account_list
  end
end
