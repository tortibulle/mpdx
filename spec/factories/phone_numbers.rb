# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :phone_number do
    person nil
    number '+11234567890'
    country_code 'MyString'
    location 'mobile'
    primary false
  end
end
