# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :relay_account, class: Person::RelayAccount do
    association :person
    remote_id 'MyString'
    first_name 'MyString'
    last_name 'MyString'
    email 'MyString'
    designation 'MyString'
    employee_id 'MyString'
    username 'MyString'
  end
end
