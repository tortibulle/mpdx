# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :contact do
    account_list
    name 'John'
    status 'Partner - Financial'
    pledge_amount 100
    pledge_frequency 1
    notes 'Test Note.'
  end
end
