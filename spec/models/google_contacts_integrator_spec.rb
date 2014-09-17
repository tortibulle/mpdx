require 'spec_helper'

describe GoogleContactsIntegrator do
  before do
    stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

    @user = create(:user)
    @account = create(:google_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @integration = create(:google_integration, google_account: @account, account_list: @account_list,
                                               contacts_integration: true, calendar_integration: false)
    @integrator = GoogleContactsIntegrator.new(@integration)

    @contact = create(:contact, account_list: @account_list, status: 'Partner - Pray', notes: 'about')

    @person = create(:person, last_name: 'Doe', middle_name: 'Henry', title: 'Mr', suffix: 'III',
                              occupation: 'Worker', employer: 'Company, Inc')
    @contact.people << @person

    @g_contact = GoogleContactsApi::Contact.new(
      'gd$etag' => 'a',
      'id' => { '$t' => '1' },
      'gd$name' => {
        'gd$givenName' => { '$t' => 'John' },
        'gd$familyName' => { '$t' => 'Doe' }
      }
    )
  end

  describe 'sync_contacts' do
    it "doesn't sync inactive contacts" do
      @contact.update_column(:status, 'Not Interested')
      expect(@integrator).to_not receive(:sync_contact)
      @integrator.sync_contacts
    end

    it 'syncs active contacts and their people' do
      expect(@integrator).to receive(:sync_contact).with(@contact)
      @integrator.sync_contacts
    end
  end

  describe 'sync_contact' do
    it 'syncs its people' do
      expect(@integrator).to receive(:sync_person).with(@person, @contact)
      @integrator.sync_contact(@contact)
    end
  end

  describe 'sync_person' do
    before do
      @g_contact_link = build(:google_contact, google_account: @account, person: @person)

      expect(@person.google_contacts).to receive(:first_or_initialize).with(google_account: @account)
                                          .and_return(@g_contact_link)
    end

    it 'creates a google contact if none retrieved/queried' do
      expect(@integrator).to receive(:get_or_query_g_contact).with(@g_contact_link, @person).and_return(nil)
      expect(@integrator).to receive(:create_g_contact).with(@person, @contact).and_return(@g_contact)
      @integrator.sync_person(@person, @contact)
    end

    it 'syncs a google contact if one is retrieved/queried' do
      expect(@integrator).to receive(:get_or_query_g_contact).with(@g_contact_link, @person).and_return(@g_contact)
      expect(@integrator).to receive(:sync_with_g_contact).with(@person, @contact, @g_contact, @g_contact_link)
      @integrator.sync_person(@person, @contact)
    end

    after do
      expect(@person.google_contacts.count).to eq(1)
      g_contact_link = @person.google_contacts.first
      expect(g_contact_link.remote_id).to eq('1')
      expect(g_contact_link.last_etag).to eq('a')
    end
  end

  describe 'get_or_query_g_contact' do
    it 'gets the g_contact if there is a remote_id in the passed google contact link record' do
      expect(@integrator).to receive(:get_g_contact).with('1').and_return('g contact')
      expect(@integrator.get_or_query_g_contact(double(remote_id: '1'), @person)).to eq('g contact')
    end

    it 'queries the g_contact if there is no remote_id in the passed google contact link record' do
      expect(@integrator).to receive(:query_g_contact).with(@person).and_return('g contact')
      expect(@integrator.get_or_query_g_contact(double(remote_id: nil), @person)).to eq('g contact')
    end
  end

  describe 'get_g_contact' do
    it 'calls the api to get a contact' do
      expect(@account.contacts_api_user).to receive(:get_contact).with('1').and_return('g contact')
      expect(@integrator.get_g_contact('1')).to eq('g contact')
    end
  end

  describe 'query_g_contact' do
    it 'queries by first and last name returns nil if no results from api query' do
      expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([])
      expect(@integrator.query_g_contact(@person)).to be_nil
    end

    it 'queries by first and last name returns nil if there are results with different name' do
      g_contact = double(given_name: 'Not-John', family_name: 'Doe')
      expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
      expect(@integrator.query_g_contact(@person)).to be_nil
    end

    it 'queries by first and last name returns match if there are results with same name' do
      g_contact = double(given_name: 'John', family_name: 'Doe')
      expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
      expect(@integrator.query_g_contact(@person)).to eq(g_contact)
    end
  end

  describe 'create_g_contact' do
    before do
      @contact.addresses_attributes = [
        { street: '2 Ln', city: 'City', state: 'MO', postal_code: '23456', country: 'United States', location: 'Business',
          primary_mailing_address: true },
        { street: '1 Way', city: 'Town', state: 'IL', postal_code: '12345', country: 'United States', location: 'Home',
          primary_mailing_address: false }
      ]
      @contact.save

      @g_contact_attrs = {
        name_prefix: 'Mr',
        given_name: 'John',
        additional_name: 'Henry',
        family_name: 'Doe',
        name_suffix: 'III',
        content: 'about',
        emails: [
          { address: 'home@example.com', primary: true, rel: 'home' },
          { address: 'john@example.com', primary: false, rel: 'work' }
        ],
        phone_numbers: [
          { number: '+12223334444', primary: true, rel: 'mobile' },
          { number: '+15552224444', primary: false, rel: 'home' }
        ],
        organizations: [
          { org_name: 'Company, Inc', org_title: 'Worker', primary: true }
        ],
        websites: [
          { href: 'www.example.com', primary: false, rel: 'other' },
          { href: 'blog.example.com', primary: true,  rel: 'other' }
        ],
        addresses: [
          { rel: 'work', primary: true,  street: '2 Ln', city: 'City', region: 'MO', postcode: '23456',
            country: 'United States of America' },
          { rel: 'home', primary: false,  street: '1 Way', city: 'Town', region: 'IL', postcode: '12345',
            country: 'United States of America' }
        ]
      }

      @person.email_address = { email: 'home@example.com', location: 'home', primary: true }
      @person.email_address = { email: 'john@example.com', location: 'work', primary: false }

      @person.phone_number = { number: '+12223334444', location: 'mobile', primary: true }
      @person.phone_number = { number: '+15552224444', location: 'home', primary: false }

      @person.websites << Person::Website.create(url: 'blog.example.com', primary: true)
      @person.websites << Person::Website.create(url: 'www.example.com', primary: false)

      @person.save
    end

    it 'calls the api to create a contact with correct attributes' do
      expect(@account.contacts_api_user).to receive(:create_contact).with(@g_contact_attrs).and_return('g contact')
      expect(@integrator.create_g_contact(@person, @contact)).to eq('g contact')
    end
  end

  describe 'sync_with_g_contact' do
    it 'syncs each of the parts, saves the records and sends the g_contact update' do
      g_contact_link = build(:google_contact, google_account: @account, person: @person)
      expect(@integrator).to receive(:sync_basic_person_fields).with(@g_contact, @person)
      expect(@integrator).to receive(:sync_contact_fields).with(@g_contact, @contact)
      expect(@integrator).to receive(:sync_employer_and_title).with(@g_contact, @person)
      expect(@integrator).to receive(:sync_emails).with(@g_contact, @person, g_contact_link)
      expect(@person).to receive(:save)
      expect(@contact).to receive(:save)
      expect(@g_contact).to receive(:send_update)
      @integrator.sync_with_g_contact(@person, @contact, @g_contact, g_contact_link)
    end
  end

  describe 'sync_contact_fields' do
    it 'sets blank mpdx notes with google contact notes' do
      @g_contact['content'] = { '$t' => 'google notes' }
      @contact.notes = ''
      @integrator.sync_contact_fields(@g_contact, @contact)
      expect(@contact.notes).to eq('google notes')
      expect(@g_contact.prepped_changes).to eq({})
    end

    it 'sets blank google contact notes to mpdx notes' do
      @g_contact['content'] = { '$t' => '' }
      @contact.notes = 'mpdx notes'
      @integrator.sync_contact_fields(@g_contact, @contact)
      expect(@contact.notes).to eq('mpdx notes')
      expect(@g_contact.prepped_changes).to eq(content: 'mpdx notes')
    end

    it 'leaves both as is if both are present' do
      @g_contact['content'] = { '$t' => 'google notes' }
      @contact.notes = 'mpdx notes'
      @integrator.sync_contact_fields(@g_contact, @contact)
      expect(@contact.notes).to eq('mpdx notes')
      expect(@g_contact.prepped_changes).to eq({})
    end
  end

  describe 'sync_basic_person_fields' do
    it 'sets blank mpdx fields with google contact fields' do
      @person.update(title: nil, first_name: '', middle_name: nil, last_name: '', suffix: '')
      @g_contact['gd$name'] = {
        'gd$namePrefix' => { '$t' => 'Mr' },
        'gd$givenName' => { '$t' => 'John' },
        'gd$additionalName' => { '$t' => 'Henry' },
        'gd$familyName' => { '$t' => 'Doe' },
        'gd$nameSuffix' => { '$t' => 'III' }
      }

      @integrator.sync_basic_person_fields(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq({})

      expect(@person.title).to eq('Mr')
      expect(@person.first_name).to eq('John')
      expect(@person.middle_name).to eq('Henry')
      expect(@person.last_name).to eq('Doe')
      expect(@person.suffix).to eq('III')
    end

    it 'sets blank google fields to mpdx fields' do
      @person.update(title: 'Mr', middle_name: 'Henry', suffix: 'III')
      @g_contact['gd$name'] = {}

      @integrator.sync_basic_person_fields(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq(name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry',
                                               family_name: 'Doe', name_suffix: 'III')
    end

    it 'leaves both as is if both are present' do
      @g_contact['gd$name'] = {
        'gd$namePrefix' => { '$t' => 'Not-Mr' },
        'gd$givenName' => { '$t' => 'Not-John' },
        'gd$additionalName' => { '$t' => 'Not-Henry' },
        'gd$familyName' => { '$t' => 'Not-Doe' },
        'gd$nameSuffix' => { '$t' => 'Not-III' }
      }
      @person.update(title: 'Mr', middle_name: 'Henry', suffix: 'III')

      @integrator.sync_basic_person_fields(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq({})

      expect(@person.title).to eq('Mr')
      expect(@person.first_name).to eq('John')
      expect(@person.middle_name).to eq('Henry')
      expect(@person.last_name).to eq('Doe')
      expect(@person.suffix).to eq('III')
    end
  end

  describe 'sync_employer_and_title' do
    it 'sets blank mpdx employer and occupation from google' do
      @person.employer = ''
      @person.occupation = nil
      @g_contact['gd$organization'] = [{
        'gd$orgName' => { '$t' => 'Company' },
        'gd$orgTitle' => { '$t' => 'Worker' }
      }]

      @integrator.sync_employer_and_title(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq({})
      expect(@person.employer).to eq('Company')
      expect(@person.occupation).to eq('Worker')
    end

    it 'sets blank google employer and occupation from mpdx' do
      @person.employer = 'Company'
      @person.occupation = 'Worker'
      @g_contact['gd$organization'] = []

      @integrator.sync_employer_and_title(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq(organizations: [{ org_name: 'Company', org_title: 'Worker',
                                                                 primary: true }])
    end

    it 'leaves both as is if both are present' do
      @person.employer = 'Company'
      @person.occupation = 'Worker'
      @g_contact['gd$organization'] = [{
        'gd$orgName' => { '$t' => 'Not-Company' },
        'gd$orgTitle' => { '$t' => 'Not-Worker' }
      }]

      @integrator.sync_employer_and_title(@g_contact, @person)

      expect(@g_contact.prepped_changes).to eq({})
      expect(@person.employer).to eq('Company')
      expect(@person.occupation).to eq('Worker')
    end
  end

  describe 'sync_emails first time sync' do
    it 'combines distinct emails from google and mpdx' do
      g_contact_link = build(:google_contact, google_account: @account, person: @person)

      @person.email_address = { email: 'mpdx@example.com', location: 'home', primary: true }
      @g_contact['gd$email'] = [
        { address: 'google@example.com', primary: 'true', rel: 'http://schemas.google.com/g/2005#other' }
      ]

      @integrator.sync_emails(@g_contact, @person, g_contact_link)

      expect(@g_contact.prepped_changes).to eq(emails: [
        { primary: true, rel: 'other', address: 'google@example.com' },
        { primary: false, rel: 'home', address: 'mpdx@example.com' }
      ])

      expect(@person.email_addresses.count).to eq(2)
      email1 = @person.email_addresses.first
      expect(email1.email).to eq('mpdx@example.com')
      expect(email1.location).to eq('home')
      expect(email1.primary).to be_true
      email2 = @person.email_addresses.last
      expect(email2.email).to eq('google@example.com')
      expect(email2.location).to eq('other')
      expect(email2.primary).to be_false
    end
  end

  describe 'mpdx_email_changes' do
    it 'properly records creates, updates and deletes since last sync' do
      email1 = double(id: 1, email: 'a')
      email2 = double(id: 2, email: 'b2')
      email4 = double(id: 4, email: 'd')
      person = double(email_addresses: [email1, email2, email4])
      g_contact_link = double(last_mappings: { emails: { 1 => 'a', 2 => 'b', 3 => 'c' } })
      expect(@integrator.mpdx_email_changes(person, g_contact_link)).to eq([
        { type: :update, old: 'b', new: 'b2', mpdx_data: email2 },
        { type: :create, new: 'd', mpdx_data: email4 },
        { type: :delete, old: 'c' }
      ])
    end
  end

  describe 'sync_emails subsequent sync' do
    before do
      @g_contact_json_text = File.new(Rails.root.join('spec/fixtures/google_contacts.json')).read
      @api_url = 'https://www.google.com/m8/feeds/contacts'
      stub_request(:get, "#{@api_url}/default/full?alt=json&max-results=100000&q=John%20Doe&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: @g_contact_json_text)

      updated_g_contact_obj = JSON.parse(@g_contact_json_text)['feed']['entry'][0]
      updated_g_contact_obj['gd$email'] = [
        { primary: true, rel: 'http://schemas.google.com/g/2005#other', address: 'johnsmith@example.com' },
        { primary: false, rel: 'http://schemas.google.com/g/2005#home', address: 'mpdx@example.com' }
      ]
      @first_sync_put = stub_request(:put, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [updated_g_contact_obj] }.to_json)

      @person.email_address = { email: 'mpdx@example.com', location: 'home', primary: true }

      @integrator.sync_contacts

      @person.reload
      expect(@person.email_addresses.count).to eq(2)
      email1 = @person.email_addresses.first
      expect(email1.email).to eq('mpdx@example.com')
      expect(email1.location).to eq('home')
      expect(email1.primary).to be_true
      email2 = @person.email_addresses.last
      expect(email2.email).to eq('johnsmith@example.com')
      expect(email2.location).to eq('other')
      expect(email2.primary).to be_false

      g_contact_link = @person.google_contacts.first
      expect(g_contact_link.remote_id).to eq('http://www.google.com/m8/feeds/contacts/test.user%40cru.org/base/6b70f8bb0372c')
      expect(g_contact_link.last_etag).to eq('"SXk6cDdXKit7I2A9Wh9VFUgORgE."')
      last_data = {
        name_prefix: 'Mr',
        given_name: 'John',
        additional_name: 'Henry',
        family_name: 'Doe',
        name_suffix: 'III',
        content: 'Notes here',
        emails: [{ primary: false, rel: 'other', address: 'johnsmith@example.com' },
                 { primary: false, rel: 'home', address: 'mpdx@example.com' }],
        phone_numbers: [{ primary: true, rel: 'mobile', number: '(123) 334-5158' }],
        addresses: [
          { primary: true, rel: 'home', country: 'United States of America',
            formatted_address: "2345 Long Dr. #232\nSomewhere\nIL\n12345\nUnited States of America",
            city: 'Somewhere', street: '2345 Long Dr. #232', region: 'IL', postcode: '12345' },
          { primary: false, rel: 'work', country: 'United States of America',
            formatted_address: "123 Big Rd\nAnywhere\nMO\n56789\nUnited States of America",
            city: 'Anywhere', street: '123 Big Rd', region: 'MO', postcode: '56789' }
        ],
        organizations: [{ primary: false, rel: 'other', org_title: 'Worker Person', org_name: 'Example, Inc' }],
        websites: [{ primary: false, rel: 'blog', href: 'blog.example.com' },
                   { primary: true, rel: 'profile', href: 'www.example.com' }]
      }
      expect(g_contact_link.last_data).to eq(last_data)

      expect(g_contact_link.last_mappings).to eq(emails: { email1.id => email1.email, email2.id => email2.email })
    end

    it 'passes on updates from mpdx to google and vice versa' do
      email = @person.email_addresses.first
      email.email = 'mpdx_MODIFIED@example.com'
      email.save

      WebMock.reset!

      updated_g_contact_obj = JSON.parse(@g_contact_json_text)['feed']['entry'][0]
      updated_g_contact_obj['gd$email'] = [
        { primary: true, rel: 'http://schemas.google.com/g/2005#other', address: 'johnsmith_MODIFIED@example.com' },
        { primary: false, rel: 'http://schemas.google.com/g/2005#home', address: 'mpdx@example.com' }
      ]
      stub_request(:get, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [updated_g_contact_obj] }.to_json)

      put_xml_regex_str = Regexp.quote('</atom:content>
        <gd:email rel="http://schemas.google.com/g/2005#other" address="johnsmith_MODIFIED@example.com"/>
        <gd:email rel="http://schemas.google.com/g/2005#home" address="mpdx_MODIFIED@example.com"/>
        <gd:phoneNumber').gsub(' ', '\s*').gsub("\n", '\s*')
      stub_request(:put, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(body: /.*#{put_xml_regex_str}.*/m, headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [updated_g_contact_obj] }.to_json)

      @integrator.sync_contacts

      @person.reload
      expect(@person.email_addresses.count).to eq(2)
      expect(@person.email_addresses.first.email).to eq('mpdx_MODIFIED@example.com')
      expect(@person.email_addresses.last.email).to eq('johnsmith_MODIFIED@example.com')
    end
  end

  # it 'creates a google contact for active contact with no google_contact link record and no existing google contact' do
  #   expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([])
  #
  #   expect(@account.contacts_api_user).to receive(:create_contact).with(@g_contact_attrs).exactly(1).times
  #                                                   .and_return(double(id: '1', etag: 'a'))
  #
  #   @integrator.sync_contacts
  #
  #   expect_correct_g_contact_link
  # end
  #
  # it 'updates google contact if there is a matching queried contact' do
  #   g_contact = GoogleContactsApi::Contact.new(
  #     'gd$etag' => 'a',
  #     'id' => { '$t' => '1' },
  #     'gd$name' => {
  #       'gd$givenName' => { '$t' => 'John' },
  #       'gd$familyName' => { '$t' => 'Doe' }
  #     }
  #   )
  #
  #   expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
  #
  #   expect(g_contact).to receive(:create_contact).with(@g_contact_attrs).exactly(1).times
  #                                         .and_return(double(id: '1', etag: 'a'))
  #
  #   @integrator.sync_contacts
  #
  #   expect_correct_g_contact_link
  # end

  # it 'doesn\'t create a contact if the person is matched to one already' do
  #   create(:google_contact, person: @person, remote_id: '1', google_account: @account)
  #
  #   expect(@account.contacts_api_user).to_not receive(:create_contact)
  #   @integrator.sync_contacts
  # end
  #
  # it 'creates a contact if person matched to a different google account' do
  #   other_google_account = create(:google_account)
  #   create(:google_contact, person: @person, remote_id: '1', google_account: other_google_account)
  #   expect(@account.contacts_api_user).to receive(:create_contact).and_return(double(id: '1'))
  #   @integrator.sync_contacts
  # end
end
