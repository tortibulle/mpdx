require 'spec_helper'

describe SetupController do
  before(:each) do
    @user = FactoryGirl.create(:user)
    sign_in(:user, @user)
  end

  describe 'show' do
    it 'should get the org_accounts step' do
      get :show, id: :org_accounts
      response.should be_success
    end

    it 'should skip the org_accounts step if the user already has an org account' do
      FactoryGirl.create(:organization_account, person: @user)
      get :show, id: :org_accounts
      response.should redirect_to('/setup/social_accounts')
    end

    it 'should get the social_accounts step' do
      FactoryGirl.create(:organization_account, person: @user)
      get :show, id: :social_accounts
      response.should be_success
    end

    it 'should redirect to the org_accounts step if the user does not have an org account' do
      get :show, id: :social_accounts
      response.should redirect_to('/setup/org_accounts')
    end

    it 'should mark setup false when finished' do
      FactoryGirl.create(:organization_account, person: @user)
      @user.update_attributes(preferences: { setup: true })
      get :show, id: :finish
      response.should redirect_to('/')
      @user.reload.setup_mode?.should == false
    end

  end
end
