# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :designation_account do
    sequence(:designation_number) { |n| n.to_s }
    association :organization
  end

  factory :designation_account_with_donor, parent: :designation_account do
    after(:create) do |designation_account, _evaluator|
      list = create(:account_list)
      create(:account_list_entry, account_list: list, designation_account: designation_account)
      contact = create(:contact, account_list: list)
      donor_account = create(:donor_account)
      create(:contact_donor_account, contact: contact, donor_account: donor_account)
    end
  end

  factory :designation_account_with_special_donor, parent: :designation_account do
    after(:create) do |designation_account, _evaluator|
      list = create(:account_list)
      create(:account_list_entry, account_list: list, designation_account: designation_account)
      contact = create(:contact, account_list: list, status: 'Partner - Special', pledge_frequency: nil, pledge_amount: nil)
      donor_account = create(:donor_account)
      create(:contact_donor_account, contact: contact, donor_account: donor_account)
    end
  end

end
