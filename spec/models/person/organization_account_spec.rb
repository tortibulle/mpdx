require 'spec_helper'

describe Person::OrganizationAccount do
  let(:org_account) { create(:organization_account) }

  context '#import_all_data' do
    it "updates the last_download column if no donations are downloaded" do
      org_account.downloading = false
      org_account.last_download = nil
      org_account.send(:import_all_data)
      org_account.reload.last_download.should be_nil
    end
  end

  context '#setup_up_account_list' do
    let(:api) { FakeApi.new }
    let(:account_list) { create(:account_list) }

    before do
      org_account.organization.stub(:api).and_return(api)
      api.stub(:profiles_with_designation_numbers).and_return([{name: 'Profile 1', code: '', designation_numbers: ['1234']}])
    end

    it "doesn't create a new list if an existing list contains only the designation number for a profile" do
      account_list.designation_accounts << create(:designation_account, designation_number: '1234')

      -> {
        org_account.send(:set_up_account_list)
      }.should_not change(AccountList, :count)
    end

    it "doesn't create a new designation profile if linking to an account list that already has one" do
      account_list.designation_accounts << create(:designation_account, designation_number: '1234')
      create(:designation_profile, name: 'Profile 1', account_list: account_list)

      -> {
        org_account.send(:set_up_account_list)
      }.should_not change(DesignationProfile, :count)
    end
  end

  context '#to_s' do
    it 'makes a pretty string' do
      org_account.to_s.should == 'MyString: foo'
    end
  end
end
