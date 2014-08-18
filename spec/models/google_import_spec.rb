require 'spec_helper'

describe GoogleImport do
  before do
    @user = create(:user)
    @account = create(:google_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @import = create(:import, source: 'google', source_account_id: @account.id, account_list: @account_list, user: @user)
    @google_import = GoogleImport.new(@import)
  end

  describe 'when importing contacts' do
    before do
      stub_request(:get, 'https://www.google.com/m8/feeds/contacts/default/full?alt=json&max-results=100000&v=3')
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: File.new(Rails.root.join('spec/fixtures/google_contacts.json')).read)
    end

    it 'should match an existing person on my list' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person)
      contact.people << person
      -> {
        @google_import.should_receive(:create_or_update_person).and_return(person)
        @google_import.send(:import_contacts)
      }.should_not change(Contact, :count)
    end

    it 'should create a new contact for someone not on my list' do
      -> {
        -> {
          @google_import.should_receive(:create_or_update_person).and_return(create(:person))
          @google_import.send(:import_contacts)
        }.should change(Person, :count).by(1)
      }.should change(Contact, :count).by(1)
    end

    it 'should add tags from the import' do
      @google_import.should_receive(:create_or_update_person).and_return(create(:person))

      @import.update_column(:tags, 'hi, mom')
      @google_import.send(:import_contacts)
      Contact.last.tag_list.sort.should == %w(hi mom)
    end
  end

  describe 'create_or_update_person' do
    before do
      @google_contact = OpenStruct.new(
          'gd$name' => { 'gd$givenName' => { '$t' => 'John' }, 'gd$familyName' => { '$t' => 'Doe' } },
          primary_email: 'john@example.com',
          id: Time.now.to_i.to_s)
    end

    it 'should update the person if they already exist' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person, first_name: 'Not-John')
      create(:google_account, person: person, remote_id: @google_contact.id)
      contact.people << person
      -> {
        @google_import.send(:create_or_update_person, @google_contact, @account_list)
        person.reload.first_name.should == 'John'
      }.should_not change(Person, :count)
    end

    it 'should create a person with an existing Master Person if a person with this google account already exists' do
      person = create(:person)
      create(:google_account, person: person, remote_id: @google_contact.id, authenticated: true)
      -> {
        -> {
          @google_import.send(:create_or_update_person, @google_contact, @account_list)
        }.should change(Person, :count)
      }.should_not change(MasterPerson, :count)
    end

    it 'should create a person and master person if we can\'t find a match' do
      -> {
        -> {
          @google_import.send(:create_or_update_person, @google_contact, @account_list)
        }.should change(Person, :count)
      }.should change(MasterPerson, :count)
    end
  end
end
