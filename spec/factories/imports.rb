# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :import do
    association :account_list
    association :user
    importing false
    source 'facebook'
  end

  factory :tnt_import, parent: :import do
    file { File.new(Rails.root.join('spec/fixtures/tnt_export.csv')) }
    source "tnt"
  end
end
