require 'spec_helper'

describe Person::RelayAccount do
  before(:each) do
    @org = create(:ccc)
    @auth_hash = Hashie::Mash.new(uid: 'JOHN.DOE@EXAMPLE.COM', extra: {attributes: [{firstName: 'John', lastName: 'Doe', username: 'JOHN.DOE@EXAMPLE.COM', email: 'johnnydoe@example.com', designation: '0000000', emplid: '000000000', ssoGuid: 'F167605D-94A4-7121-2A58-8D0F2CA6E024'}]})
  end
  describe 'find or create from auth' do
    it 'should create an account linked to a person' do
      person = create(:user)
      @org.stub!(:api).and_return(FakeApi.new)
      create(:organization_account, person: person, organization: @org)
      -> {
        @account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, person)
      }.should change(Person::RelayAccount, :count).from(0).to(1)
      person.relay_accounts.should include(@account)
    end

    it "should gracefully handle a duplicate" do
      @person = create(:user)
      @person2 = create(:user)
      @org.stub!(:api).and_return(FakeApi.new)
      create(:organization_account, person: @person, organization: @org)
      create(:organization_account, person: @person2, organization: @org)
      @account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, @person)
      -> {
        @account2 = Person::RelayAccount.find_or_create_from_auth(@auth_hash, @person2)
      }.should_not change(Person::RelayAccount, :count)
      @account.should == @account2
    end

  end

  describe 'create user from auth' do
    it "should create a user with a first and last name" do
      -> {
        user = Person::RelayAccount.create_user_from_auth(@auth_hash)
        user.first_name.should == @auth_hash.extra.attributes.first.firstName
        user.last_name.should == @auth_hash.extra.attributes.first.lastName
      }.should change(User, :count).from(0).to(1)
    end
  end

  it 'should use guid to find an authenticated user' do
    user = create(:user)
    @org.stub!(:api).and_return(FakeApi.new)
    create(:organization_account, person_id: user.id, organization: @org)
    account = Person::RelayAccount.find_or_create_from_auth(@auth_hash, user)
    Person::RelayAccount.find_authenticated_user(@auth_hash).should == user
  end

  it 'should return name for to_s' do
    account = Person::RelayAccount.new(username: 'foobar@example.com')
    account.to_s.should == 'foobar@example.com'
  end
end
