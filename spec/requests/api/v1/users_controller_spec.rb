require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::UsersController do
  context '#show' do
    let(:user) { create(:user_with_account) }

    before do
      stub_auth
      get '/api/v1/users/me?access_token=' + user.access_token
    end

    it 'respond with success' do
      expect(response.status).to eq(200)
    end
  end

  context '#update' do
    let(:user) { create(:user_with_account) }

    before do
      stub_auth
    end

    it 'saves contact filters' do
      account_list = user.account_lists.first

      put '/api/v1/users/me', access_token: user.access_token, user: { preferences: { contacts_filter: { account_list.id => { tags: 'foo' }}}}
      expect(response.status).to eq(200)
      expect(assigns(:user).preferences[:contacts_filter][account_list.id.to_s][:tags]).to eq('foo')
    end
  end
end
