# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :import do
    association :account_list
    source "tnt"
    importing false
    file { File.new(Rails.root.join('spec/fixtures/tnt_export.csv')) }
  end
end
