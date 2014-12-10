require 'spec_helper'

describe Person::RelayAccount do
  before(:each) do
    @org = create(:ccc)
    user_attributes = [{ firstName: 'John', lastName: 'Doe', username: 'JOHN.DOE@EXAMPLE.COM',
                         email: 'johnnydoe@example.com', designation: '0000000', emplid: '000000000',
                         ssoGuid: 'F167605D-94A4-7121-2A58-8D0F2CA6E024' }]
    @auth_hash = Hashie::Mash.new(uid: 'JOHN.DOE@EXAMPLE.COM', extra: { attributes: user_attributes })
    @wsapi_headers = { 'Accept' => '*/*; q=0.5, application/xml', 'Accept-Encoding' => 'gzip, deflate',
                       'Authorization' => "Bearer #{APP_CONFIG['itg_auth_key']}", 'User-Agent' => 'Ruby' }
    stub_request(:get, 'https://wsapi.ccci.org/wsapi/rest/profiles?response_timeout=60000&ssoGuid=F167605D-94A4-7121-2A58-8D0F2CA6E024')
      .with(headers: @wsapi_headers)
      .to_return(status: 200, body: '[]', headers: {})
  end
  describe 'find or create from auth' do
    it 'should create an account linked to a person' do
      person = create(:user)
      @org.stub(:api).and_return(FakeApi.new)
      expect {
        @account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, person)
      }.to change(Person::RelayAccount, :count).from(0).to(1)
      person.relay_accounts.should include(@account)
    end

    it 'should gracefully handle a duplicate' do
      @person = create(:user)
      @person2 = create(:user)
      @org.stub(:api).and_return(FakeApi.new)
      @account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, @person)
      expect {
        @account2 = Person::RelayAccount.find_or_create_from_auth(@auth_hash, @person2)
      }.to_not change(Person::RelayAccount, :count)
      @account.should == @account2
    end

    it 'creates an organization account if this user has a profile at cru' do
      stub_request(:get, 'https://wsapi.ccci.org/wsapi/rest/profiles?response_timeout=60000&ssoGuid=F167605D-94A4-7121-2A58-8D0F2CA6E024')
        .with(headers: @wsapi_headers)
        .to_return(status: 200, headers: {},
                   body: '[{"name":"Staff Account(000555555)","designations":[{"number":"0555555","description":"Jon and Jane Doe(000555555)","staffAccountId":"000555555"}]}]')
      person = create(:user)
      @org.stub(:api).and_return(FakeApi.new)
      expect {
        @account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, person)
      }.to change(Person::OrganizationAccount, :count).from(0).to(1)
    end

  end

  describe 'create user from auth' do
    it 'should create a user with a first and last name' do
      expect {
        user = Person::RelayAccount.create_user_from_auth(@auth_hash)
        user.first_name.should eq @auth_hash.extra.attributes.first.firstName
        user.last_name.should eq @auth_hash.extra.attributes.first.lastName
      }.to change(User, :count).from(0).to(1)
    end
  end

  it 'should use guid to find an authenticated user' do
    user = create(:user)
    @org.stub(:api).and_return(FakeApi.new)
    Person::RelayAccount.find_or_create_from_auth(@auth_hash, user)
    Person::RelayAccount.find_authenticated_user(@auth_hash).should eq user
  end

  it 'should return name for to_s' do
    account = Person::RelayAccount.new(username: 'foobar@example.com')
    account.to_s.should == 'foobar@example.com'
  end
end
