require 'spec_helper'

describe GoogleImport do
  before do
    @user = create(:user)
    @account = create(:google_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @import = create(:import, source: 'google', source_account_id: @account.id, account_list: @account_list, user: @user)
    @google_import = GoogleImport.new(@import)

    stub_request(:get, 'https://www.google.com/m8/feeds/contacts/default/full?alt=json&max-results=100000&v=3')
      .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
      .to_return(body: File.new(Rails.root.join('spec/fixtures/google_contacts.json')).read)

    stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')
  end

  describe 'when importing contacts' do
    it 'should match an existing person on my list' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person)
      contact.people << person
      -> {
        @google_import.should_receive(:create_or_update_person).and_return(person)
        @google_import.send(:import_contacts)
      }.should_not change(Contact, :count)
    end

    it 'should create a new contact for someone not on my list and ignore contact without first name' do
      # note the json file has a blank contact record which should be ignored, so the count changes by 1 only
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
      @google_contact = OpenStruct.new(given_name: 'John', family_name: 'Doe',
                                       emails_full: [], phone_numbers_full: [],
                                       id: Time.now.to_i.to_s)
    end

    it 'should update the person if they already exist by google remote_id' do
      contact = create(:contact, account_list: @account_list)
      person = create(:person, first_name: 'Not-John')
      create(:google_account, person: person, remote_id: @google_contact.id)
      contact.people << person
      -> {
        @google_import.send(:create_or_update_person, @google_contact, @account_list)
        person.reload.first_name.should == 'John'
      }.should_not change(Person, :count)
    end

    it 'should update a person if their name matches' do
      contact = create(:contact, account_list: @account_list)
      contact.people << create(:person, last_name: 'Doe')
      contact.save
      -> {
        @google_import.send(:create_or_update_person, @google_contact, @account_list)
      }.should_not change(Person, :count)
    end

    it 'should create a person with an existing Master Person if a person with this google account already exists' do
      person = create(:person, email: nil) # check that nil email works OK
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

  describe 'overall import results' do
    it 'should import correct person data if no people exist' do
      @google_import.send(:import_contacts)

      expect(@account_list.people.to_a.count).to eq(1)
      expect(@account_list.contacts.to_a.count).to eq(1)

      person = @account_list.people.to_a.first
      contact = @account_list.contacts.to_a.first

      expect(contact.people).to include(person)
      expect(person.contacts).to include(contact)
      expect(contact.name).to eq('Doe, John')
      expect(person.first_name).to eq('John')
      expect(person.last_name).to eq('Doe')

      expect(contact.addresses.to_a.count).to eq(2)
      address1 = contact.addresses.order(:postal_code).first
      expect(address1.country).to eq('United States')
      expect(address1.city).to eq('Somewhere')
      expect(address1.street).to eq('2345 Long Dr. #232')
      expect(address1.state).to eq('IL')
      expect(address1.postal_code).to eq('12345')
      address2 = contact.addresses.order(:postal_code).last
      expect(address2.country).to eq('United States')
      expect(address2.city).to eq('Anywhere')
      expect(address2.street).to eq('123 Big Rd')
      expect(address2.state).to eq('MO')
      expect(address2.postal_code).to eq('56789')

      expect(person.email_addresses.to_a.count).to eq(1)
      email = person.email_addresses.to_a.first
      expect(email.email).to eq('johnsmith@example.com')
      expect(email.location).to eq('other')
      expect(email.primary).to be_true

      expect(person.phone_numbers.to_a.count).to eq(1)
      phone = person.phone_numbers.to_a.first
      expect(phone.number).to eq('+11233345158')
      expect(phone.location).to eq('mobile')
      expect(phone.primary).to be_false
    end
  end

  describe 'import by group' do
    it 'should do nothing if no groups specified' do
      @import.import_by_group = true
      @import.save
      -> {
        @google_import.send(:import_contacts)
      }.should_not change(Contact, :count)
    end

    it 'should import a specified group' do
      @import.import_by_group = true
      group_url = 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6'
      @import.groups = [group_url]
      @import.group_tags = {
        'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6' => 'more, tags'
      }
      @import.tags = 'hi, mom'
      @import.save

      stub_request(:get, "https://www.google.com/m8/feeds/contacts/default/full?alt=json&group=#{URI.escape(group_url)}&max-results=100000&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: File.new(Rails.root.join('spec/fixtures/google_contacts.json')).read)
        .times(1)

      -> {
        @google_import.send(:import_contacts)
      }.should change(Contact, :count).by(1)

      Contact.last.tag_list.sort.should == %w(hi mom more tags)
    end
  end
end
