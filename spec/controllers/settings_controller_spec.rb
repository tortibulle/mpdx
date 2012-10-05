require 'spec_helper'

describe SettingsController do

  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
    @contact = create(:contact, account_list: @user.account_lists.first)
  end

  describe "GET 'integrations'" do
    it "returns http success" do
      get 'integrations'
      response.should be_success
    end
  end

end
