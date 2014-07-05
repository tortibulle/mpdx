# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :master_address do
    street 'MyText'
    city 'MyString'
    state 'MyString'
    country 'MyString'
    postal_code 'MyString'
  end
end
