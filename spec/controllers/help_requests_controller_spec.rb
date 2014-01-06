require 'spec_helper'

describe HelpRequestsController do
  let(:user) { create(:user_with_account) }
  let(:valid_attributes) { { name: 'foo', email: 'foo@example.com', problem: 'bar', request_type: 'baz' } }

  before do
    sign_in(:user, user)
  end

  context '#new' do
    it 'gets form' do
      get :new
      response.should be_success
    end
  end

  context '#create' do
    it 'saves a valid submission' do
      post :create, help_request: valid_attributes

      response.should render_template('help_requests/thanks')
    end

    it 'shows the form again if the submission was invalid' do
      post :create, help_request: {name: ''}

      response.should render_template('help_requests/new')
    end

  end

end
