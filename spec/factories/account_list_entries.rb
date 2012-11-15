# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :account_list_entry do
    account_list
    designation_account
  end
end
