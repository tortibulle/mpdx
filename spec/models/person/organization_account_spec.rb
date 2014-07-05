require 'spec_helper'

describe Person::OrganizationAccount do
  let(:org_account) { create(:organization_account) }
  let(:api) { FakeApi.new }

  before do
    org_account.organization.stub(:api).and_return(api)
    api.stub(:profiles_with_designation_numbers).and_return([{ name: 'Profile 1', code: '', designation_numbers: ['1234'] }])
  end

  context '#import_all_data' do
    it 'updates the last_download column if no donations are downloaded' do
      org_account.downloading = false
      org_account.last_download = nil
      org_account.send(:import_all_data)
      org_account.reload.last_download.should be_nil
    end

    context 'when password error' do
      before do
        api.stub(:import_all).and_raise(OrgAccountInvalidCredentialsError)
        org_account.person.email = 'foo@example.com'

        org_account.downloading = false
        org_account.locked_at = nil
        org_account.new_record?.should be false
      end
      it 'rescues invalid password error' do
        expect {
          org_account.import_all_data
        }.to_not raise_error
      end
      it 'sends email' do
        org_account.import_all_data
        ActionMailer::Base.deliveries.last.to.first.should == org_account.person.email.email
      end
      it 'marks as not valid' do
        org_account.import_all_data
        org_account.valid_credentials.should be false
      end
    end
  end

  context '#setup_up_account_list' do
    let(:account_list) { create(:account_list) }

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
