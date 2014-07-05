# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :activity_comment do
    activity nil
    person nil
    body 'MyText'
  end
end
