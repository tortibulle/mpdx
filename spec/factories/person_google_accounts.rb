# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :google_account do
    remote_id "MyString"
    person nil
    token "MyString"
    refresh_token "MyString"
    expires_at "2012-02-08 14:04:10"
    valid_token false
  end
end
