require 'spec_helper'

describe User do
  describe 'user role' do
    describe 'from omniauth' do
      before(:each) do
        @auth_hash = Hashie::Mash.new(uid: 'JOHN.DOE@EXAMPLE.COM', extra: { attributes: [{ firstName: 'John', lastName: 'Doe', username: 'JOHN.DOE@EXAMPLE.COM', email: 'johnnydoe@example.com', designation: '0000000', emplid: '000000000', ssoGuid: 'F167605D-94A4-7121-2A58-8D0F2CA6E024' }] })
      end

      it 'should create a new user from omniauth' do
        FactoryGirl.create(:ccc)
        expect {
          User.from_omniauth(Person::RelayAccount, @auth_hash)
        }.to change(User, :count).from(0).to(1)
      end

    end
  end

  describe 'fundraiser role' do
    before(:each) do
      @org = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
      FactoryGirl.create(:designation_profile, organization: @org, user: @user)
      @account = FactoryGirl.create(:designation_account, organization: @org)
      @account_list = FactoryGirl.create(:account_list)
      FactoryGirl.create(:account_list_entry, account_list: @account_list, designation_account: @account)
      FactoryGirl.create(:account_list_user, account_list: @account_list, user: @user)
    end

    it 'should return a list of account numbers from a given org' do
      @user.designation_numbers(@org.id).should include(@account.designation_number)
    end

  end
end
