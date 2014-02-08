require 'spec_helper'

describe Api::V1::ContactsController do
  describe 'api' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first, pledge_amount: 100) }

    context '#count' do
      it "succeeds" do
        get :count, access_token: user.access_token
        response.should be_success
      end
    end

    context '#index' do
      it 'filters address out' do
        get :index, access_token: user.access_token, include: 'Contact.name,Contact.id,Contact.avatar'
        response.should be_success
        json = JSON.parse(response.body)
        json.should_not include 'address'
        json.should include 'contacts'
        json['contacts'][0].should include 'id'
        json['contacts'][0].should include 'avatar'
        json['contacts'][0].should_not include 'pledge_amount'
      end
    end
    
  end
end
