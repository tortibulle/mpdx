require 'spec_helper'

describe Api::V1::ContactsController do
  describe 'api' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first) }

    it "gets count" do
      get :count, access_token: user.access_token
      response.should be_success
    end
  end
end
