require 'spec_helper'

describe Person::TwitterAccount do
  describe 'create from auth' do
    it 'should create an account linked to a person' do
      auth_hash = Hashie::Mash.new(extra: {access_token: {params: {user_id: 5, screen_name: 'foo', oauth_token: 'a', oauth_token_secret: 'b'}}})
      person = FactoryGirl.create(:person)
      -> {
        @account = Person::TwitterAccount.find_or_create_from_auth(auth_hash, person)
      }.should change(Person::TwitterAccount, :count).from(0).to(1)
      person.twitter_accounts.should include(@account)
    end
  end
  describe 'update from auth' do
    it 'should update an account that already exists' do
      auth_hash = Hashie::Mash.new(extra: {access_token: {params: {user_id: 5, screen_name: 'foo', oauth_token: 'a', oauth_token_secret: 'b'}}})
      person = FactoryGirl.create(:person)
      Person::TwitterAccount.find_or_create_from_auth(auth_hash, person)
      -> {
        @account = Person::TwitterAccount.find_or_create_from_auth(auth_hash, person)
      }.should_not change(Person::TwitterAccount, :count)
    end
  end

  it 'should return screen name for to_s' do
    account = Person::TwitterAccount.new(screen_name: 'Doe')
    account.to_s.should == 'Doe'
  end
end
