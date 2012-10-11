require 'spec_helper'

describe SocialStreamsController do

  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
  end

  describe "GET 'index'" do
    it "should get recent posts for a contact" do
      create(:facebook_account, person: @user)
      @contact = create(:contact, account_list: @user.account_lists.first)
      @contact.people << create(:person)
      create(:facebook_account, person: @contact.people.first)
      stub_request(:get, /https:\/\/graph.facebook.com\/.*\/posts\?access_token=.*/).
         to_return(:status => 200, :body => '{"data":[{"id":"500015648_10151284672575649","from":{"name":"JoshStarcher","id":"500015648"},"story":"\"AmIwinning?\"onhisownstatus.","type":"status","created_time":"2012-10-07T12:58:11+0000","updated_time":"2012-10-07T12:58:11+0000","comments":{"count":0}}]}', :headers => {})

      get 'index', contact_id: @contact.id
      response.should be_success
      assigns(:items).length.should == 1
    end
  end

end
