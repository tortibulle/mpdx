require 'spec_helper'

describe Person::GoogleAccount do
  describe 'create from auth' do
    it 'should create an account linked to a person' do
      auth_hash = Hashie::Mash.new(uid: '1',
                                   info: { email: 'foo@example.com' },
                                   credentials: { token: 'a', refresh_token: 'b', expires: true, expires_at: Time.now.to_i + 100 })
      person = FactoryGirl.create(:person)
      expect {
        @account = Person::GoogleAccount.find_or_create_from_auth(auth_hash, person)
      }.to change(Person::GoogleAccount, :count).from(0).to(1)
      person.google_accounts.should include(@account)
    end
  end
  describe 'update from auth' do
    it 'should update an account that already exists' do
      auth_hash = Hashie::Mash.new(uid: '1',
                                   info: { email: 'foo@example.com' },
                                   credentials: { token: 'a', refresh_token: 'b', expires: true, expires_at: Time.now.to_i + 100 })
      person = FactoryGirl.create(:person)
      Person::GoogleAccount.find_or_create_from_auth(auth_hash, person)
      expect {
        @account = Person::GoogleAccount.find_or_create_from_auth(auth_hash.merge!(credentials: { refresh_token: 'c' }), person)
      }.to_not change(Person::GoogleAccount, :count)
      @account.refresh_token.should == 'c'
    end
  end

  it 'should return email for to_s' do
    account = Person::GoogleAccount.new(email: 'john.doe@example.com')
    account.to_s.should == 'john.doe@example.com'
  end

end
