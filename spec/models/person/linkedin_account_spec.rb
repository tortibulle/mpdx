require 'spec_helper'

describe Person::LinkedinAccount do
  describe 'create from auth' do
    it 'should create an account linked to a person' do
      auth_hash = Hashie::Mash.new(uid: '5',
                                   credentials: {token: 'a', secret: 'b'},
                                   extra: {access_token: {params: {oauth_expires_in: 2, oauth_authorization_expires_in: 5}}},
                                   info: {first_name: 'John', last_name: 'Doe'}
                                  )
      person = FactoryGirl.create(:person)
      -> {
        @account = Person::LinkedinAccount.find_or_create_from_auth(auth_hash, person)
      }.should change(Person::LinkedinAccount, :count).from(0).to(1)
      person.linkedin_accounts.should include(@account)
    end
  end
  it 'should return name for to_s' do
    account = Person::LinkedinAccount.new(first_name: 'John', last_name: 'Doe')
    account.to_s.should == 'John Doe'
  end


end
