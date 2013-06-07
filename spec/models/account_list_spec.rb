require 'spec_helper'

describe AccountList do

  context '.find_or_create_from_profile' do
    let(:org_account) { create(:organization_account) }
    let(:profile) { create(:designation_profile, user_id: org_account.person_id, organization: org_account.organization) }

    it "should create a new account list if none is found" do
      da = create(:designation_account, organization: org_account.organization)
      profile.designation_accounts << da
      expect {
        AccountList.find_or_create_from_profile(profile, org_account)
      }.to change(AccountList, :count).by(1)
    end

    it "should not create a new account list if one is found" do
      da = create(:designation_account, organization: org_account.organization)
      profile.designation_accounts << da
      account_list = create(:account_list)
      profile2 = create(:designation_profile, account_list: account_list)
      profile2.designation_accounts << da
      expect(AccountList.find_or_create_from_profile(profile, org_account))
          .to eq(account_list)
    end
  end

end
