# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :person do
    first_name 'John'
    association :master_person
  end
end
