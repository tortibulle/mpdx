require 'spec_helper'

describe Person::OrganizationAccount do
  before(:each) do
    @org_account = create(:organization_account)
  end

  describe "import_all_data" do
    it "should update the last_download column" do
      @org_account.downloading = false
      @org_account.last_download = nil
      @org_account.send(:import_all_data)
      @org_account.reload.last_download.should_not be_nil
    end
  end

  describe "setup_up_account_list" do
    before(:each) do
      @api = FakeApi.new
      @org_account.organization.stub!(:api).and_return(@api)
      @api.stub!(:profiles_with_designation_numbers).and_return([{name: 'Profile 1', code: '', designation_numbers: ['1234']}])
    end

    it "should create a new account list if none is found" do
      -> {
        @org_account.send(:set_up_account_list)
      }.should change(AccountList, :count)
    end

    it 'should not create a new list if an existing list contains only the designation number for a profile' do
      @account_list = create(:account_list)
      @account_list.designation_accounts << create(:designation_account, designation_number: '1234')
      -> {
        @org_account.send(:set_up_account_list)
      }.should_not change(AccountList, :count)
    end

    # it 'should not show duplicate designation_profiles'
  end
end
