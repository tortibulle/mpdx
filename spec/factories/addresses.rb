# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :address do
    association :addressable, factory: :contact
    street "MyString"
    city "MyString"
    state "MyString"
    country "MyString"
    postal_code "MyString"
    location "Home"
    start_date "2012-02-19"
    end_date "2012-02-19"
  end
end
