require 'spec_helper'

describe Person::FacebookAccount do
  before do
    @user = create(:user)
    @account = create(:facebook_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @import = create(:import, source: 'facebook', source_account_id: @account.id, account_list: @account_list, user: @user)
    @facebook_import = FacebookImport.new(@import)
  end

  describe 'when importing contacts' do
    before do
      stub_request(:get, "https://graph.facebook.com/#{@account.remote_id}/friends?access_token=#{@account.token}")
        .to_return(body: '{"data": [{"name": "David Hylden","id": "120581"}]}')
      stub_request(:get, "https://graph.facebook.com/120581?access_token=#{@account.token}")
        .to_return(body: '{"id": "120581", "first_name": "John", "last_name": "Doe", "relationship_status": "Married", "significant_other":{"id":"120582"}}')
      stub_request(:get, "https://graph.facebook.com/120582?access_token=#{@account.token}")
        .to_return(body: '{"id": "120582", "first_name": "Jane", "last_name": "Doe"}')
    end

    it 'should match an existing person on my list' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person)
      contact.people << person
      expect {
        @facebook_import.should_receive(:create_or_update_person).and_return(person)
        @facebook_import.should_receive(:create_or_update_person).and_return(create(:person)) # spouse
        @facebook_import.send(:import_contacts)
      }.to_not change(Contact, :count)
    end

    it 'should create a new contact for someone not on my list (or married to someone on my list)' do
      spouse = create(:person)
      @facebook_import.should_receive(:create_or_update_person).and_return(spouse)
      expect {
        expect {
          @facebook_import.should_receive(:create_or_update_person).and_return(create(:person))
          @facebook_import.send(:import_contacts)
        }.to change(Person, :count).by(1)
      }.to change(Contact, :count).by(1)
    end

    it 'should match a person to their spouse if the spouse is on my list' do
      contact = create(:contact, account_list: @account_list)
      spouse = create(:person)
      contact.people << spouse
      # spouse_account
      create(:facebook_account, person: spouse, remote_id: '120582')
      expect {
        expect {
          @facebook_import.should_receive(:create_or_update_person).and_return(create(:person))
          @facebook_import.should_receive(:create_or_update_person).and_return(spouse)

          @facebook_import.send(:import_contacts)
        }.to change(Person, :count).by(1)
      }.to_not change(Contact, :count)
    end

    it 'should add tags from the import' do
      @import.update_column(:tags, 'hi, mom')
      @facebook_import.send(:import_contacts)
      Contact.last.tag_list.sort.should == %w(hi mom)
    end
  end

  describe 'create_or_update_person' do
    before do
      @friend = OpenStruct.new(first_name: 'John',
                               identifier: Time.now.to_i.to_s,
                               raw_attributes: { 'birthday' => '01/02' })
    end
    it 'should update the person if they already exist' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person, first_name: 'Not-John')
      create(:facebook_account, person: person, remote_id: @friend.identifier)
      contact.people << person
      expect {
        @facebook_import.send(:create_or_update_person, @friend, @account_list)
        person.reload.first_name.should == 'John'
      }.to_not change(Person, :count)
    end

    it 'should create a person with an existing Master Person if a person with this FB accoun already exists' do
      person = create(:person)
      create(:facebook_account, person: person, remote_id: @friend.identifier, authenticated: true)
      expect {
        expect {
          @facebook_import.send(:create_or_update_person, @friend, @account_list)
        }.to change(Person, :count)
      }.to_not change(MasterPerson, :count)
    end

    it "should create a person and master peson if we can't find a match" do
      expect {
        expect {
          @facebook_import.send(:create_or_update_person, @friend, @account_list)
        }.to change(Person, :count)
      }.to change(MasterPerson, :count)

    end

  end

end
