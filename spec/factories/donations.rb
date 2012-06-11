# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :donation do
    remote_id "MyString"
    association :donor_account
    association :designation_account
    motivation "MyString"
    payment_method "MyString"
    tendered_currency "MyString"
    tendered_amount "9.99"
    currency "MyString"
    amount "9.99"
    memo "MyText"
    donation_date "2012-03-14"
  end
end
