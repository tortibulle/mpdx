# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :master_person_donor_account do
    master_person nil
    donor_account nil
    primary false
  end
end
