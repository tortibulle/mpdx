require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::ContactsController do
  describe 'api' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first) }

    before do
      stub_auth
      get '/api/v1/contacts?access_token=' + user.access_token
    end

    it 'responds 200' do
      response.code.should == '200'
    end
  end
end
