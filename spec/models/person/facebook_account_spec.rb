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

  describe 'when importing contacts' do
    before do
      @account_list = create(:account_list)
      @import = create(:import, source: 'facebook', account_list: @account_list)
      @account = create(:facebook_account)
      stub_request(:get, "https://graph.facebook.com/#{@account.remote_id}/friends?access_token=MyString").
         to_return(:body => '{"data": [{"name": "David Hylden","id": "120581"}]}')
      stub_request(:get, "https://graph.facebook.com/120581?access_token=MyString").
         to_return(:body => '{"id": "120581", "first_name": "John", "last_name": "Doe", "relationship_status": "Married", "significant_other":{"id":"120582"}}')
      stub_request(:get, "https://graph.facebook.com/120582?access_token=MyString").
        to_return(:body => '{"id": "120582", "first_name": "Jane", "last_name": "Doe"}')
    end

    it 'should match an existing person on my list' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person)
      contact.people << person
      -> {
        @account.should_receive(:create_or_update_person).and_return(person)
        @account.should_receive(:create_or_update_person).and_return(create(:person)) # spouse
        @account.send(:import_contacts, @import.id)
      }.should_not change(Contact, :count)
    end

    it 'should create a new contact for someone not on my list (or married to someone on my list)' do
      stub_request(:get, "https://graph.facebook.com/120581/family?access_token=MyString").
         to_return(:body => '{"data": []}')
      spouse = create(:person)
      @account.should_receive(:create_or_update_person).and_return(spouse)
      -> {
        -> {
          @account.should_receive(:create_or_update_person).and_return(create(:person))
          @account.send(:import_contacts, @import.id)
        }.should change(Person, :count).by(1)
      }.should change(Contact, :count).by(1)
    end

    it 'should match a person to their spouse if the spouse is on my list' do
      contact = create(:contact, account_list: @account_list)
      spouse = create(:person)
      contact.people << spouse
      spouse_account = create(:facebook_account, person: spouse, remote_id: '120582')
      -> {
        -> {
          @account.should_receive(:create_or_update_person).and_return(create(:person))
          @account.should_receive(:create_or_update_person).and_return(spouse)

          @account.send(:import_contacts, @import.id)
        }.should change(Person, :count).by(1)
      }.should_not change(Contact, :count)
    end

    it "should add tags from the import" do
      @import.update_column(:tags, 'hi, mom')
      @account.send(:import_contacts, @import.id)
      Contact.last.tag_list.sort.should == ['hi', 'mom']
    end
  end

  describe 'create_or_update_person' do
    before do
      @friend = OpenStruct.new(first_name: 'John',
                               identifier: Time.now.to_i.to_s,
                               raw_attributes: {'birthday' => '01/02'})
      @account_list = create(:account_list)
      @fb_account = create(:facebook_account)
    end
    it "should update the person if they already exist" do
      contact = create(:contact, account_list: @account_list)
      person = create(:person, first_name: 'Not-John')
      account = create(:facebook_account, person: person, remote_id: @friend.identifier)
      contact.people << person
      -> {
        @fb_account.send(:create_or_update_person, @friend, @account_list)
        person.reload.first_name.should == 'John'
      }.should_not change(Person, :count)
    end

    it "should create a person with an existing Master Person if a person with this FB accoun already exists" do
      person = create(:person)
      account = create(:facebook_account, person: person, remote_id: @friend.identifier, authenticated: true)
      -> {
        -> {
          @fb_account.send(:create_or_update_person, @friend, @account_list)
        }.should change(Person, :count)
      }.should_not change(MasterPerson, :count)
    end

    it "should create a person and master peson if we can't find a match" do
      -> {
        -> {
          @fb_account.send(:create_or_update_person, @friend, @account_list)
        }.should change(Person, :count)
      }.should change(MasterPerson, :count)

    end
  end

end
