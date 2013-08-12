# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :prayer_letters_account do
    key "MyString"
    secret "MyString"
    account_list nil
  end
end
