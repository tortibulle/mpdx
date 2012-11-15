# Read about factories at http://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :designation_account do
    designation_number "1234567"
    association :organization
  end

  factory :designation_account_with_donor, parent: :designation_account do
    after(:create) do |designation_account, evaluator|
      list = create(:account_list)
      create(:account_list_entry, account_list: list, designation_account: designation_account)
      contact = create(:contact, account_list: list)
      donor_account = create(:donor_account)
      create(:contact_donor_account, contact: contact, donor_account: donor_account)
    end
  end

end
