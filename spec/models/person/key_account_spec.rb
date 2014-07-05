require 'spec_helper'

describe Person::KeyAccount do
  before(:each) do
    @auth_hash = Hashie::Mash.new(uid: 'john.doe@example.com', extra: { attributes: [{ firstName: 'John', lastName: 'Doe', email: 'johnnydoe@example.com', ssoGuid: 'F167605D-94A4-7121-2A58-8D0F2CA6E024' }] })
  end
  describe 'create from auth' do
    it 'should create an account linked to a person' do
      person = FactoryGirl.create(:person)
      -> {
        @account = Person::KeyAccount.find_or_create_from_auth(@auth_hash, person)
      }.should change(Person::KeyAccount, :count).from(0).to(1)
      person.key_accounts.should include(@account)
    end
  end

  describe 'create user from auth' do
    it 'should create a user with a first and last name' do
      -> {
        user = Person::KeyAccount.create_user_from_auth(@auth_hash)
        user.first_name.should == @auth_hash.extra.attributes.first.firstName
        user.last_name.should == @auth_hash.extra.attributes.first.lastName
      }.should change(User, :count).from(0).to(1)
    end
  end

  it 'should use guid to find an authenticated user' do
    user = FactoryGirl.create(:user)
    account = Person::KeyAccount.find_or_create_from_auth(@auth_hash, user)
    Person::KeyAccount.find_authenticated_user(@auth_hash).should == user
  end

  it 'should return name for to_s' do
    account = Person::KeyAccount.new(email: 'foobar@example.com')
    account.to_s.should == 'foobar@example.com'
  end
end
