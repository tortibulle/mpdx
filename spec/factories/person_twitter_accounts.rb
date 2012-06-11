# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :twitter_account do
    person_id 1
    remote_id 1
    screen_name "MyString"
    token "MyString"
    secret "MyString"
  end
end
