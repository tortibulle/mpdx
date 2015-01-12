require 'spec_helper'

describe GoogleImport do
  before do
    @user = create(:user)
    @account = create(:google_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @contact = create(:contact, account_list: @account_list)
    @import = create(:import, source: 'google', source_account_id: @account.id, account_list: @account_list, user: @user)
    @google_import = GoogleImport.new(@import)

    stub_g_contacts('spec/fixtures/google_contacts.json')
    stub_g_contact_photo
    stub_smarty_and_cloudinary
  end

  def stub_g_contacts(file)
    stub_request(:get, 'https://www.google.com/m8/feeds/contacts/default/full?alt=json&max-results=100000&v=3')
      .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
      .to_return(body: File.new(Rails.root.join(file)).read)
  end

  def stub_g_contact_photo
    stub_request(:get, 'https://www.google.com/m8/feeds/photos/media/test.user@cru.org/6b70f8bb0372c?v=3')
      .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
      .to_return(body: 'photo data', headers: { 'content-type' => 'image/jpeg' })
  end

  def stub_smarty_and_cloudinary
    stub_request(:get, %r{https://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

    # Based on sample from docs at http://cloudinary.com/documentation/upload_images
    cloudinary_reponse = {
      url: 'http://res.cloudinary.com/cru/image/upload/v1/img.jpg',
      secure_url: 'https://res.cloudinary.com/cru/image/upload/v1/img.jpg',
      public_id: 'img',
      version: '1',
      width: 864,
      height: 564,
      format: 'jpg',
      resource_type: 'image',
      signature: 'abcdefgc024acceb1c5baa8dca46797137fa5ae0c3'
    }.to_json
    stub_request(:post, 'https://api.cloudinary.com/v1_1/cru/auto/upload').to_return(body: cloudinary_reponse)
  end

  describe 'when importing contacts' do
    it 'matches an existing person on my list' do
      person = create(:person)
      @contact.people << person
      expect {
        @google_import.should_receive(:create_or_update_person).and_return(person)
        @google_import.import
      }.to_not change(Contact, :count)
    end

    it 'creates a new contact for someone not on my list and ignore contact without first name' do
      # note the json file has a blank contact record which should be ignored, so the count changes by 1 only
      expect {
        expect {
          @google_import.should_receive(:create_or_update_person).and_return(create(:person))
          @google_import.import
        }.to change(Person, :count).by(1)
      }.to change(Contact, :count).by(1)
    end

    it 'adds tags from the import' do
      @google_import.should_receive(:create_or_update_person).and_return(create(:person))

      @import.update_column(:tags, 'hi, mom')
      @google_import.import
      Contact.last.tag_list.sort.should == %w(hi mom)
    end
  end

  describe 'create_or_update_person' do
    before do
      @google_contact = OpenStruct.new(given_name: 'John', family_name: 'Doe',
                                       emails_full: [], phone_numbers_full: [], organizations: [],
                                       websites: [], id: Time.now.to_i.to_s)
    end

    it 'updates the person if they already exist by google remote_id if override set' do
      @import.override = true
      person = create(:person, first_name: 'Not-John')
      create(:google_contact, person: person, remote_id: @google_contact.id)
      @contact.people << person
      expect {
        @google_import.send(:create_or_update_person, @google_contact)
        person.reload.first_name.should == 'John'
      }.to_not change(Person, :count)
    end

    it 'does not create a new person if their name matches' do
      @contact.people << create(:person, first_name: 'John', last_name: 'Doe')
      expect {
        @google_import.send(:create_or_update_person, @google_contact)
      }.to_not change(Person, :count)
    end

    it "creates a person and master person if we can't find a match" do
      expect {
        expect {
          @google_import.send(:create_or_update_person, @google_contact)
        }.to change(Person, :count)
      }.to change(MasterPerson, :count)
    end
  end

  describe 'spouse import' do
    def stub_g_contacts_with_spouse(spouse)
      file = 'spec/fixtures/google_contacts.json'
      json = JSON.parse(File.new(Rails.root.join(file)).read)
      json['feed']['entry'][0]['gContact$relation'] = [{ 'rel' => 'spouse', '$t' => spouse }]
      stub_request(:get, 'https://www.google.com/m8/feeds/contacts/default/full?alt=json&max-results=100000&v=3')
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: json.to_json)
    end

    it 'does not import a spouse if none specified' do
      @google_import.import
      contact = Contact.find_by_name('Google, John')
      expect(contact.people.count).to eq(1)
    end

    def import_and_expect_names(contact_name, person1_name, person2_name)
      @google_import.import
      contact = Contact.find_by_name(contact_name)
      people_names = contact.people.map { |p| [p.first_name, p.last_name] }
      expect(people_names.size).to eq(2)
      expect(people_names).to include(person1_name)
      expect(people_names).to include(person2_name)
    end

    it 'imports a spouse with a first name and assumes same last name' do
      stub_g_contacts_with_spouse('Jane')
      import_and_expect_names('Google, John and Jane', %w(John Google), %w(Jane Google))
    end

    it 'imports a spouse with a different last name' do
      stub_g_contacts_with_spouse('Jane Smith')
      import_and_expect_names('Google, John and Jane (Smith)', %w(John Google), %w(Jane Smith))
    end

    it 'imports a spouse with a compound first name and a last name' do
      stub_g_contacts_with_spouse('Mary Beth Smith')
      import_and_expect_names('Google, John and Mary Beth (Smith)', %w(John Google), ['Mary Beth', 'Smith'])
    end

    it 'does not import spouse or change contact name if spouse person already exists in contact' do
      @contact.update(name: 'Google, John')
      john = create(:person, first_name: 'John', last_name: 'Google')
      jane = create(:person, first_name: 'Jane', last_name: 'Google', middle_name: 'Already there')
      @contact.people << john
      @contact.people << jane

      stub_g_contacts_with_spouse('Jane')
      @google_import.import
      expect(Contact.count).to eq(1)
      contact = Contact.first
      expect(contact).to eq(@contact)
      expect(contact.people).to include(john)
      expect(contact.people).to include(jane)
      expect(contact.people.map(&:middle_name)).to include('Already there')
    end
  end

  describe 'overall import results' do
    def check_imported_data
      contacts = @account_list.contacts.where(name: 'Google, John')
      expect(contacts.to_a.count).to eq(1)
      contact = contacts.first

      expect(contact.people.count).to eq(1)
      person = contact.people.first

      expect(contact.people).to include(person)
      expect(person.contacts).to include(contact)
      expect(contact.name).to eq('Google, John')
      expect(person.first_name).to eq('John')
      expect(person.last_name).to eq('Google')
      expect(person.middle_name).to eq('Henry')
      expect(person.title).to eq('Mr')
      expect(person.suffix).to eq('III')
      expect(person.birthday_year).to eq(1988)
      expect(person.birthday_month).to eq(5)
      expect(person.birthday_day).to eq(12)
      expect(person.employer).to eq('Example, Inc')
      expect(person.occupation).to eq('Worker Person')

      expect(person.websites.to_a.count).to eq(2)
      website1 = person.websites.order(:url).first
      expect(website1.url).to eq('blog.example.com')
      expect(website1.primary).to be_false
      website2 = person.websites.order(:url).last
      expect(website2.url).to eq('www.example.com')
      expect(website2.primary).to be_true

      expect(contact.notes).to eq('Notes here')

      expect(contact.addresses.to_a.count).to eq(2)
      address1 = contact.addresses.order(:postal_code).first
      expect(address1.country).to eq('United States')
      expect(address1.city).to eq('Somewhere')
      expect(address1.street).to eq('2345 Long Dr. #232')
      expect(address1.state).to eq('IL')
      expect(address1.postal_code).to eq('12345')
      expect(address1.primary_mailing_address).to be_true
      address2 = contact.addresses.order(:postal_code).last
      expect(address2.country).to eq('United States')
      expect(address2.city).to eq('Anywhere')
      expect(address2.street).to eq('123 Big Rd')
      expect(address2.state).to eq('MO')
      expect(address2.postal_code).to eq('56789')

      expect(person.email_addresses.to_a.count).to eq(1)
      email = person.email_addresses.order(:email).first
      expect(email.email).to eq('johnsmith@example.com')
      expect(email.location).to eq('other')
      expect(email.primary).to be_true

      expect(person.phone_numbers.to_a.count).to eq(1)
      phone = person.phone_numbers.order(:number).first
      expect(phone.number).to eq('+11233345158')
      expect(phone.location).to eq('mobile')
      expect(phone.primary).to be_true

      expect(person.pictures.count).to eq(1)
      picture = person.pictures.first
      expect(picture.image.url).to eq('http://res.cloudinary.com/cru/image/upload/v1/img.jpg')
      expect(picture.primary).to be_true

      expect(person.google_contacts.count).to eq(1)
      google_contact = person.google_contacts.first
      expect(google_contact.google_account).to eq(@account)
      expect(google_contact.picture_etag).to eq('dxt2DAEZfCp7ImA-AV4zRxBoPG4UK3owXBM.')
      expect(google_contact.picture).to eq(picture)
    end

    it 'imports correct person data if no people exist and be the same for repeat imports' do
      @google_import.import
      check_imported_data

      # Repeat the import and make sure the data is the same
      @google_import.import
      check_imported_data
    end

    it 'handles the case when the Google auth token cannot be refreshed' do
      expect_any_instance_of(Person::GoogleAccount).to receive(:contacts_api_user)
                                                       .at_least(1).times.and_raise(Person::GoogleAccount::MissingRefreshToken)
      expect { @google_import.import }.to raise_error(Import::UnsurprisingImportError)
      expect(@account_list.contacts.count).to eq(1)
    end
  end

  describe 'import override/non-override behavior for primary contact info' do
    before do
      @contact.addresses_attributes = [{
        street: '1 Way', city: 'Town', state: 'IL', postal_code: '22222',
        country: 'United States', location: 'Home', primary_mailing_address: true
      }]
      @contact.save
      @person = build(:person, last_name: 'Google')
      @person.email_address = { email: 'existing_primary@example.com', primary: true }
      @person.phone_number = { number: '474-747-4744', primary: true }
      @person.websites << Person::Website.create(url: 'original.example.com', primary: true)
      @person.save
      @contact.people << @person
    end

    it 'makes imported phone/email/address primary if set to override (and marked as primary in imported data)' do
      @import.override = true
      @google_import.import

      @contact.reload
      expect(@contact.primary_address.street).to eq('2345 Long Dr. #232')

      @person.reload
      expect(@person.primary_email_address.email).to eq('johnsmith@example.com')
      expect(@person.primary_phone_number.number).to eq('+11233345158')
      expect(@person.website.url).to eq('www.example.com')
    end

    it 'does not not make imported phone/email/address primary if not set to override' do
      @import.override = false
      @google_import.import

      @contact.reload
      expect(@contact.primary_address.street).to eq('1 Way')

      @person.reload
      expect(@person.primary_email_address.email).to eq('existing_primary@example.com')
      expect(@person.primary_phone_number.number).to eq('+14747474744')
      expect(@person.website.url).to eq('original.example.com')
    end
  end

  it 'assigns the last website a primary role if no websites existed before and none imported are marked as primary' do
    person = create(:person, last_name: 'Doe')
    @contact.people << person
    g_contact = double(websites: [{ href: 'example.com' }, { href: 'other.example.com' }])
    @google_import.update_person_websites(person, g_contact)
    person.reload
    expect(person.websites.count).to eq(2)
    website1 = person.websites.order(:url).first
    expect(website1.url).to eq('example.com')
    expect(website1.primary).to be_false
    website2 = person.websites.order(:url).last
    expect(website2.url).to eq('other.example.com')
    expect(website2.primary).to be_true
  end

  describe 'import override behavior for basic fields' do
    before do
      @existing_contact = create(:contact, account_list: @account_list, notes: 'Original notes')
      @existing_person = create(:person, first_name: 'Not-John', last_name: 'Not-Doe',
                                         middle_name: 'Not-Henry', title: 'Not-Mr', suffix: 'Not-III')
      remote_id = 'http://www.google.com/m8/feeds/contacts/test.user%40cru.org/base/6b70f8bb0372c'
      @existing_person.google_contacts << create(:google_contact, remote_id: remote_id)
      @original_picture = create(:picture, picture_of: @existing_person, primary: true)
      @existing_person.pictures << @original_picture
      @existing_contact.people << @existing_person
    end

    it 'updates fields if set to override' do
      @import.override = true
      @google_import.import
      @existing_person.reload
      @existing_contact.reload
      expect(@existing_contact.notes).to eq('Notes here')
      expect(@existing_person.first_name).to eq('John')
      expect(@existing_person.last_name).to eq('Google')
      expect(@existing_person.middle_name).to eq('Henry')
      expect(@existing_person.title).to eq('Mr')
      expect(@existing_person.suffix).to eq('III')

      @original_picture.reload
      expect(@original_picture.primary).to be_false
      expect(@existing_person.pictures.count).to eq(2)
      expect(@existing_person.primary_picture.image.url).to eq('http://res.cloudinary.com/cru/image/upload/v1/img.jpg')
    end

    it 'does not not update fields if not set to override' do
      @import.override = false
      @google_import.import
      @existing_person.reload
      @existing_contact.reload
      expect(@existing_contact.notes).to eq('Original notes')
      expect(@existing_person.first_name).to eq('Not-John')
      expect(@existing_person.last_name).to eq('Not-Doe')
      expect(@existing_person.middle_name).to eq('Not-Henry')
      expect(@existing_person.title).to eq('Not-Mr')
      expect(@existing_person.suffix).to eq('Not-III')

      @original_picture.reload

      # Check that it does add the picture but doesn't set it to primary
      expect(@original_picture.primary).to be_true
      expect(@existing_person.pictures.count).to eq(2)
      expect(@existing_person.primary_picture.image.url).to be_nil
    end

    it 'updates notes fields if they were blank even if set to not override' do
      @existing_contact.update notes: ''
      @existing_person.pictures.first.destroy
      @import.override = false
      @google_import.import
      @existing_person.reload
      @existing_contact.reload
      expect(@existing_contact.notes).to eq('Notes here')

      expect(@existing_person.pictures.count).to eq(1)
      expect(@existing_person.primary_picture.image.url).to eq('http://res.cloudinary.com/cru/image/upload/v1/img.jpg')
    end
  end

  it "doesn't import a picture if the person has an associated facebook account" do
    person = build(:person)
    @contact.people << person
    create(:facebook_account, person: person)
    @google_import.import
    expect(person.pictures.count).to eq(0)
  end

  describe 'import by group' do
    it 'does nothing if no groups specified' do
      @import.import_by_group = true
      @import.save
      expect {
        @google_import.import
      }.to_not change(Contact, :count)
    end

    it 'imports a specified group' do
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

      expect {
        @google_import.import
      }.to change(Contact, :count).by(1)

      Contact.last.tag_list.sort.should == %w(hi mom more tags)
    end

    it 'handles the case when the Google auth token cannot be refreshed' do
      expect_any_instance_of(Person::GoogleAccount).to receive(:contacts_api_user)
                                                       .at_least(1).times.and_raise(Person::GoogleAccount::MissingRefreshToken)
      expect { @google_import.import }.to raise_error(Import::UnsurprisingImportError)
      expect(@account_list.contacts.count).to eq(1)
    end
  end

  describe 'import primary field default' do
    it "'assigns one arbitrary address/email/phone/website as primary if MPDX and Google didn't specify primary" do
      WebMock.reset!

      stub_g_contacts('spec/fixtures/google_contacts_no_primary.json')
      stub_g_contact_photo
      stub_smarty_and_cloudinary

      @import.override = false
      @google_import.import

      contact = @account_list.contacts.where(name: 'Doe, John').first
      person = contact.people.first

      expect(person.websites.to_a.count).to eq(2)
      website1 = person.websites.order(:url).first
      website2 = person.websites.order(:url).last
      expect(website1.primary || website2.primary).to be_true
      expect(website1.primary && website2.primary).to be_false

      expect(contact.addresses.to_a.count).to eq(2)
      address1 = contact.addresses.order(:postal_code).first
      address2 = contact.addresses.order(:postal_code).last
      expect(address1.primary_mailing_address || address1.primary_mailing_address).to be_true
      expect(address2.primary_mailing_address && address2.primary_mailing_address).to be_false

      expect(person.email_addresses.to_a.count).to eq(2)
      email1 = person.email_addresses.order(:email).first
      email2 = person.email_addresses.order(:email).last
      expect(email1.primary || email1.primary).to be_true
      expect(email2.primary && email2.primary).to be_false

      expect(person.phone_numbers.to_a.count).to eq(2)
      phone1 = person.phone_numbers.order(:number).first
      phone2 = person.phone_numbers.order(:number).last
      expect(phone1.primary || phone1.primary).to be_true
      expect(phone2.primary && phone2.primary).to be_false

      expect(person.pictures.count).to eq(1)
      picture = person.pictures.first
      expect(picture.primary).to be_true
    end
  end
end
