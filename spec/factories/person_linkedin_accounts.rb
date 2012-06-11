# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :linkedin_account do
    person_id 1
    remote_id 1
    token "MyString"
    secret "MyString"
    token_expires_at "2012-02-02 16:51:29"
  end
end
