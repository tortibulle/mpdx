# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    association :master_person
    first_name 'John'
    preferences {{setup: false}}
  end

  factory :user_with_account, parent: :user do
    after :create do |u|
      FactoryGirl.create(:organization_account, person: u)
      account_list = FactoryGirl.create(:account_list)
      FactoryGirl.create(:account_list_user, {user: u, account_list: account_list})
    end
  end
end
