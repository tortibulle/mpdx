require 'spec_helper'

describe Person::FacebookAccount do
  describe 'when authenticating' do
    before do
      @auth_hash = Hashie::Mash.new(uid: '5', credentials: {token: 'a', expires_at: 5}, info: {first_name: 'John', last_name: 'Doe'})
    end
    describe 'create from auth' do
      it 'should create an account linked to a person' do
        person = create(:person)
        -> {
          @account = Person::FacebookAccount.find_or_create_from_auth(@auth_hash, person)
        }.should change(Person::FacebookAccount, :count).from(0).to(1)
        person.facebook_accounts.should include(@account)
      end
    end

    describe 'create user from auth' do
      it "should create a user with a first and last name" do
        -> {
          user = Person::FacebookAccount.create_user_from_auth(@auth_hash)
          user.first_name.should == @auth_hash.info.first_name
          user.last_name.should == @auth_hash.info.last_name
        }.should change(User, :count).from(0).to(1)
      end
    end

    it 'should use uid to find an authenticated user' do
      user = create(:user)
      account = Person::FacebookAccount.find_or_create_from_auth(@auth_hash, user)
      Person::FacebookAccount.find_authenticated_user(@auth_hash).should == user
    end

  end

  it 'should return name for to_s' do
    account = Person::FacebookAccount.new(first_name: 'John', last_name: 'Doe')
    account.to_s.should == 'John Doe'
  end

  it "should generate a facebook url if there is a remote_id" do
    account = Person::FacebookAccount.new(remote_id: 1)
    account.url.should == "http://facebook.com/profile.php?id=1"
  end

  describe 'setting facebook id from a url' do
    before do
      @account = Person::FacebookAccount.new
    end

    it "should get an id from a url containing a name" do
      @account.should_receive(:get_id_from_url).and_return(1)
      @account.url = 'https://www.facebook.com/john.doe'
      @account.remote_id.should == 1
    end

    it "should get an id from a url containing a profile id" do
      @account.should_receive(:get_id_from_url).and_return(1)
      @account.url = 'https://www.facebook.com/profile.php?id=1'
      @account.remote_id.should == 1
    end

    it "delete the account if the name is not found" do
      #stub_request(:get, /https:\/\/graph.facebook.com\/.*/).
         #with(:headers => {'Accept'=>'application/json'}).to_return(:status => 404)
      @account.should_receive(:get_id_from_url).and_raise(RestClient::ResourceNotFound)
      @account.url = 'https://www.facebook.com/john.doe'
      @account.frozen?.should == true # deleted
    end

  end

  describe 'get id from url' do
    before do
      @account = Person::FacebookAccount.new
    end

    it "when url contains profile id" do
      @account.get_id_from_url('https://www.facebook.com/profile.php?id=1').should == 1
    end

    it "when url contains permalink" do
      stub_request(:get, /https:\/\/graph.facebook.com\/.*/).
         with(:headers => {'Accept'=>'application/json'}).to_return(:status => 200, :body => '{"id": 1}')
      @account.get_id_from_url('https://www.facebook.com/john.doe').should == 1
    end

    it "should raise an exception if the url is bad" do
      stub_request(:get, /https:\/\/graph.facebook.com\/.*/).
         with(:headers => {'Accept'=>'application/json'}).to_return(:status => 404)
      lambda {@account.get_id_from_url('https://www.facebook.com/john.doe')}.should raise_error(RestClient::ResourceNotFound)
    end

  end

end
