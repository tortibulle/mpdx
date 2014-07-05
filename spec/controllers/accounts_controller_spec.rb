require 'spec_helper'

describe AccountsController do
  describe 'when not signed in' do
    before do
      @user = create(:user_with_account)
      auth_hash = Hashie::Mash.new(uid: '5', credentials: { token: 'a', expires_at: 5 }, info: { first_name: 'John', last_name: 'Doe' })
      account = Person::FacebookAccount.find_or_create_from_auth(auth_hash, @user)
      request.env['omniauth.auth'] = auth_hash
    end
    it 'should sign a user in' do
      post 'create', provider: 'facebook'
      request.session['warden.user.user.key'].should == [[@user.id], nil]
    end

    it 'should queue data imports on sign in' do
      User.should_receive(:from_omniauth).and_return(@user)
      @user.should_receive(:queue_imports)
      post 'create', provider: 'facebook'
    end

    it 'redirects to the homepage if someone tries to connect to google without a session' do
      post 'create', provider: 'google'
      assert_redirected_to '/'
    end
  end

  describe 'when signed in' do
    before(:each) do
      @user = create(:user_with_account)
      sign_in(:user, @user)
    end

    describe 'GET index' do
      it 'should be successful' do
        get :index
        response.should be_success
      end
    end

    describe "POST 'create'" do
      it 'creates an account' do
        mash = Hashie::Mash.new(uid: '5', credentials: { token: 'a', expires_at: 5 }, info: { first_name: 'John', last_name: 'Doe' })
        request.env['omniauth.auth'] = mash
        -> {
          post 'create', provider: 'facebook'
          response.should redirect_to(accounts_path)
          @user.facebook_accounts.should include(assigns(:account))
        }.should change(Person::FacebookAccount, :count).from(0).to(1)
      end

      it 'should redirect to social accounts if the user is in setup mode' do
        @user.update_attributes(preferences: { setup: true })
        Person::FacebookAccount.stub(:find_or_create_from_auth)
        post 'create', provider: 'facebook'
        response.should redirect_to(setup_path(:social_accounts))
      end

      it 'should redirect to a stored user_return_to' do
        session[:user_return_to] = '/foo'
        Person::FacebookAccount.stub(:find_or_create_from_auth)
        post 'create', provider: 'facebook'
        response.should redirect_to('/foo')
      end

    end

    describe "GET 'destroy'" do
      it 'returns http success' do
        @account = FactoryGirl.create(:facebook_account, person: @user)
        -> {
          get 'destroy', provider: 'facebook', id: @account.id
          response.should redirect_to(accounts_path)
        }.should change(Person::FacebookAccount, :count).from(1).to(0)
      end
    end

    describe "GET 'failure'" do
      it 'redirects to index' do
        get 'failure'
        flash[:alert].should_not == nil
        response.should redirect_to(accounts_path)
      end
    end

  end
end
