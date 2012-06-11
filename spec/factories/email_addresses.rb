# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :email_address do
    person nil
    email "MyString"
    primary false
  end
end
