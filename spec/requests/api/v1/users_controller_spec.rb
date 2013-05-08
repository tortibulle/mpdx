require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::UsersController do
  describe 'api' do
    let(:user) { create(:user_with_account) }

    before do
      stub_auth
      get "/api/v1/users/me?access_token="+user.access_token
    end

    it "respond with success" do
      response.code.should == "200"
    end
  end
end
