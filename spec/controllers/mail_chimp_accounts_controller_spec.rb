require 'spec_helper'

describe MailChimpAccountsController do
  let(:valid_attributes) { { api_key: 'foo-us4', primary_list_id: 'asdf' } }

  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
    @account_list = @user.account_lists.first
    controller.stub(:current_account_list).and_return(@account_list)
    @contact = create(:contact, account_list: @account_list)
  end

  context 'index' do
    let(:chimp) { create(:mail_chimp_account, account_list: @account_list) }

    before do
      @account_list.stub(:mail_chimp_account).and_return(chimp)
    end

    it 'should validate the current key if there is a mail chimp account' do
      chimp.should_receive(:validate_key).and_return(false)
      chimp.stub(:primary_list)

      get :index
    end

    it "should redirect to the 'new' page if the current account is not active" do
      chimp.stub(:validate_key)

      chimp.should_receive(:active?).and_return(false)

      get :index

      response.should redirect_to(new_mail_chimp_account_path)
    end

    it "should redirect to the 'edit' page if there is no primary list" do
      chimp.stub(:validate_key)
      chimp.stub(:active)

      chimp.should_receive(:primary_list).and_return(false)

      get :index

      response.should redirect_to(edit_mail_chimp_account_path(chimp))
    end

  end

  context '#create' do
    it 'creates a new mailchimp account' do
      stub_request(:post, 'https://us4.api.mailchimp.com/1.3/?method=lists')
          .with(body: '%7B%22apikey%22%3A%22foo-us4%22%7D')
          .to_return(status: 200, body: '{"total": 0,"data": []}', headers: {})

      expect {
        post :create, mail_chimp_account: valid_attributes
      }.to change(MailChimpAccount, :count).by(1)
    end
  end
end
