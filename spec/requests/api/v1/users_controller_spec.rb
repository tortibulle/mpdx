require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::UsersController do
  describe 'when signed in' do
    let(:user) { create(:user_with_account) }

    before do
      stub_auth
      get "/api/v1/users/me?access_token="+user.access_token
    end
    let(:body) { JSON.parse(response.body) }

    it "respond with success" do
      response.code.should == "200"
    end

    it "account lists" do 
      body.should include 'account_lists'
      body['account_lists'].length.should eq user.account_lists.length
    end
    describe "account" do
      subject { body['account_lists'][0] }
      it { should include 'id' }
      it { should include 'name' }
      it { should include 'designation_account_ids' }
    end
  end
end
