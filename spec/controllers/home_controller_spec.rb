require 'spec_helper'

describe HomeController do
  render_views

  describe "when not logged in" do
    describe "GET 'index'" do
      it "redirects to splash page" do
        get 'index'
        response.should redirect_to('/login')
      end

      it "should use relay on us domain" do
        request.host = 'us'
        get 'index'
        response.should redirect_to('/auth/relay')
      end

      it "should use key on secure domain" do
        request.host = 'mpdxs'
        get 'index'
        response.should redirect_to('/auth/key')
      end

    end
    describe 'login' do
      it "returns http success" do
        get 'login'
        response.should be_success
      end
    end
  end

  describe "when logged in" do
    before(:each) do
      @user = FactoryGirl.create(:user_with_account)
      sign_in(:user, @user)
    end
    describe "GET 'index'" do
      it "returns http success" do
        get 'index'
        response.should be_success
      end

      it 'should redirect to setup if user is still in setup mode' do
        @user.update_attributes(preferences: {setup: true})
        get 'index'
        response.should redirect_to('/setup/org_accounts')
      end

      it 'should include graph' do
        @user.account_lists.first.update_attributes(monthly_goal: "100")
        get 'index'
        response.should render_template("donations_summary_chart")
      end
    end
  end

end
