require 'spec_helper'

describe PreferencesController do
  let(:user) { create(:user_with_account) }

  before(:each) do
    sign_in(:user, user)
  end

  context '#index' do
    it 'gets the index' do
      get :index
      response.should be_success
      assigns(:preference_set).user.should == user
    end
  end

  context '#update' do
    it "updates successfully" do
      request.env["HTTP_REFERER"] = 'back'
      put :update, id: 1, preference_set: {first_name: 'John', email: 'john@example.com'}
      response.should redirect_to(request.env["HTTP_REFERER"])
    end

    it "renders errors when update fails" do
      put :update, id: 1, preference_set: {}
      response.should be_success
      flash.alert.should == "Email can't be blank"
    end
  end
end
