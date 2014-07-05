FactoryGirl.define do
  factory :task do
    association :account_list
    starred false
    location 'MyString'
    subject 'MyString'
    start_at '2012-03-08 14:59:46'
    activity_type 'Call'
  end
end
