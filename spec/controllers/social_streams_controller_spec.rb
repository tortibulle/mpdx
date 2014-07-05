require 'spec_helper'

describe SocialStreamsController do

  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
  end

  describe "GET 'index'" do
    it 'should get recent posts for a contact' do
      create(:facebook_account, person: @user)
      @contact = create(:contact, account_list: @user.account_lists.first)
      @contact.people << create(:person)
      create(:facebook_account, person: @contact.people.first)
      stub_request(:get, /https:\/\/graph.facebook.com\/fql.*\?access_token=.*/)
        .to_return(status: 200, body: '{"data":[{"name":"query1","fql_result_set":[{"post_id":"3214624_10101555060433253","actor_id":3214624,"target_id":null,"action_links":null,"attachment":{"description":""},"message":"","description":"TinaAdamsandAustinSheelerarenowfriends.","type":8,"created_time":1358790500}]},{"name":"query2","fql_result_set":[{"uid":3214624,"name":"TinaAdams"}]}]}', headers: {})

      get 'index', contact_id: @contact.id
      response.should be_success
      assigns(:items).length.should == 1
    end
  end

end
