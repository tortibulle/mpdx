# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :family_relationship do
    association :person
    association :related_person, :factory => :person
    relationship "MyString"
  end
end
