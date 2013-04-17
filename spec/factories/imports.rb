# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :import do
    association :account_list
    association :user
    importing false
    source 'facebook'
    after :create do |i|
      i.user.email_addresses << create(:email_address)
    end
  end

  factory :tnt_import, parent: :import do
    file { File.new(Rails.root.join('spec/fixtures/tnt_export.xml')) }
    source "tnt"
  end

  factory :tnt_import_non_donor, parent: :tnt_import do
    file { File.new(Rails.root.join('spec/fixtures/tnt_export_non_donor.xml')) }
  end
end
