# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :company_position do
    person nil
    company nil
    start_date "2012-03-09"
    end_date "2012-03-09"
    position "MyString"
  end
end
