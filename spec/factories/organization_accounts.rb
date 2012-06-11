# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :organization_account, class: 'Person::OrganizationAccount' do
    association :person
    association :organization, factory: :fake_org
    username 'foo'
    password 'bar'
    authenticated true
    valid_credentials true
    remote_id 1
  end
end
