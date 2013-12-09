# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :linkedin_account, class: Person::LinkedinAccount do
    association :person
    remote_id 1
    token "MyString"
    secret "MyString"
    token_expires_at { 1.day.from_now }
  end
end
