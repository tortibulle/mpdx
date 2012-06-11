# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :facebook_account, class: 'Person::FacebookAccount' do
    association :person
    sequence(:remote_id) {|n| n}
    token "MyString"
  end
end
