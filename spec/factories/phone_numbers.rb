# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phone_number do
    person nil
    number "MyString"
    country_code "MyString"
    location "MyString"
    primary false
  end
end
