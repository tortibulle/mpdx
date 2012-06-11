# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :master_person_source do
    master_person nil
    organization nil
    remote_id "MyString"
  end
end
