# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :address do
    association :addressable, factory: :contact
    association :master_address
    street "123 Somewhere St"
    city "Fremont"
    state "CA"
    country "United States"
    postal_code "94539"
    location "Home"
    start_date "2012-02-19"
    end_date "2012-02-19"
  end
end
