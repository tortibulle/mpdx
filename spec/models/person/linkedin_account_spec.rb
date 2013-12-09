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

  it 'adds http:// to url if necessary' do
    account = build(:linkedin_account)
    Person::LinkedinAccount.should_receive(:valid_token).and_return([account])
    stub_request(:get, "https://api.linkedin.com/v1/people/url=http:%2F%2Fwww.linkedin.com%2Fpub%2Fchris-cardiff%2F6%2Fa2%2F62a:(id,first-name,last-name,public-profile-url)").
      to_return(:status => 200, :body => '{"first_name":"Chris","id":"F_ZUsSGtL7","last_name":"Cardiff","public_profile_url":"http://www.linkedin.com/pub/chris-cardiff/6/a2/62a"}', :headers => {})

    url = 'www.linkedin.com/pub/chris-cardiff/6/a2/62a'
    l = Person::LinkedinAccount.new(url: url)
    expect(l.url).to eq('http://' + url)
  end


end
