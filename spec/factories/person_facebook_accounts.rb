# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :facebook_account, class: 'Person::FacebookAccount' do
    association :person
    sequence(:remote_id) { |n| n.to_s }
    token 'TokenString'
    token_expires_at { 1.day.from_now }
  end
end
