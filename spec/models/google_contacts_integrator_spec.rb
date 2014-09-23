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
      'gd$name' => { 'gd$givenName' => { '$t' => 'John' }, 'gd$familyName' => { '$t' => 'Doe' } }
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

  describe 'sync_person' do
    before do
      expect(@integrator).to receive(:find_or_build_g_contact_link).with(@person)
                                            .and_return(@g_contact_link)

    end

    it 'creates a google contact if none retrieved/queried' do
      expect(@integrator).to receive(:get_or_query_g_contact).with(@g_contact_link, @person).and_return(nil)
      expect(@integrator).to receive(:new_g_contact).with(@person).and_return('new g_contact')
      expect(@integrator.sync_person(@person)).to eq(['new g_contact', @g_contact_link])
    end

    it 'syncs a google contact if one is retrieved/queried' do
      expect(@integrator).to receive(:get_or_query_g_contact).with(@g_contact_link, @person).and_return(@g_contact)
      expect(@integrator).to receive(:sync_with_g_contact).with(@person, @g_contact, @g_contact_link)
      expect(@integrator.sync_person(@person)).to eq([@g_contact, @g_contact_link])
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

  describe 'new_g_contact' do
    before do
      @contact.addresses_attributes = [
        { street: '2 Ln', city: 'City', state: 'MO', postal_code: '23456', country: 'United States', location: 'Business',
          primary_mailing_address: true },
        { street: '1 Way', city: 'Town', state: 'IL', postal_code: '12345', country: 'United States', location: 'Home',
          primary_mailing_address: false }
      ]
      @contact.save

      @g_contact_attrs = {
        name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry', family_name: 'Doe', name_suffix: 'III',
        emails: [
          { primary: true, rel: 'home', address: 'home@example.com' },
          { primary: false, rel: 'work', address: 'john@example.com' }
        ],
        phone_numbers: [
          { number: '(222) 333-4444', primary: true, rel: 'mobile' },
          { number: '(555) 222-4444', primary: false, rel: 'home' }
        ],
        organizations: [
          { org_name: 'Company, Inc', org_title: 'Worker', primary: true }
        ],
        websites: [
          { href: 'www.example.com', primary: false, rel: 'other' },
          { href: 'blog.example.com', primary: true,  rel: 'other' }
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
      expect(@integrator.new_g_contact(@person).prepped_changes).to eq(@g_contact_attrs)
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

  describe 'ensure_single_primary_address' do
    it 'sets all but the first primary address in the list to do not primary' do
      address1 = build(:address, primary_mailing_address: true)
      address2 = build(:address, primary_mailing_address: false)
      address3 = build(:address, primary_mailing_address: true)
      @integrator.ensure_single_primary_address([address1, address2, address3])
      expect(address1.primary_mailing_address).to be_true
      expect(address2.primary_mailing_address).to be_false
      expect(address3.primary_mailing_address).to be_false
    end
  end

  describe 'sync emails' do
    it 'combines distinct emails from google and mpdx' do
      g_contact_link = build(:google_contact, google_account: @account, person: @person, last_data: { emails: [] })

      @person.email_address = { email: 'mpdx@example.com', location: 'home', primary: true }

      @g_contact.update('gd$email' => [
        { 'address' => 'google@example.com', 'primary' => 'true', 'rel' => 'http://schemas.google.com/g/2005#other' }
      ])

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

  describe 'sync numbers' do
    it 'combines and formats numbers from mpdx and google' do
      g_contact_link = build(:google_contact, google_account: @account, person: @person, last_data: { phone_numbers: [] })

      @person.phone_number = { number: '+12223334444', location: 'mobile', primary: true }

      @g_contact.update('gd$phoneNumber' => [
        { '$t' => '(777) 888-9999', 'primary' => 'true', 'rel' => 'http://schemas.google.com/g/2005#other' }
      ])

      @integrator.sync_numbers(@g_contact, @person, g_contact_link)

      expect(@g_contact.prepped_changes).to eq(phone_numbers: [
        { number: '(777) 888-9999', primary: true, rel: 'other' },
        { number: '(222) 333-4444', primary: false, rel: 'mobile' }
      ])

      expect(@person.phone_numbers.count).to eq(2)
      phone1 = @person.phone_numbers.first
      expect(phone1.number).to eq('+12223334444')
      expect(phone1.location).to eq('mobile')
      expect(phone1.primary).to be_true
      phone2 = @person.phone_numbers.last
      expect(phone2.number).to eq('+17778889999')
      expect(phone2.location).to eq('other')
      expect(phone2.primary).to be_false
    end
  end

  describe 'sync addresses' do
    before do
      WebMock.reset!

      richmond_smarty = '[{"input_index":0,"candidate_index":0,"delivery_line_1":"7229 Forest Ave Ste 208","last_line":"Richmond VA 23226-3765","delivery_point_barcode":"232263765581","components":{"primary_number":"7229","street_name":"Forest","street_suffix":"Ave","secondary_number":"208","secondary_designator":"Ste","city_name":"Richmond","state_abbreviation":"VA","zipcode":"23226","plus4_code":"3765","delivery_point":"58","delivery_point_check_digit":"1"},"metadata":{"record_type":"H","zip_type":"Standard","county_fips":"51087","county_name":"Henrico","carrier_route":"C023","congressional_district":"07","rdi":"Commercial","elot_sequence":"0206","elot_sort":"A","latitude":37.60519,"longitude":-77.52963,"precision":"Zip9","time_zone":"Eastern","utc_offset":-5.0,"dst":true},"analysis":{"dpv_match_code":"Y","dpv_footnotes":"AABB","dpv_cmra":"N","dpv_vacant":"N","active":"Y","footnotes":"N#"}}]'
      anchorage_smary = '[{"input_index":0,"candidate_index":0,"delivery_line_1":"2421 E Tudor Rd Ste 102","last_line":"Anchorage AK 99507-1166","delivery_point_barcode":"995071166277","components":{"primary_number":"2421","street_predirection":"E","street_name":"Tudor","street_suffix":"Rd","secondary_number":"102","secondary_designator":"Ste","city_name":"Anchorage","state_abbreviation":"AK","zipcode":"99507","plus4_code":"1166","delivery_point":"27","delivery_point_check_digit":"7"},"metadata":{"record_type":"H","zip_type":"Standard","county_fips":"02020","county_name":"Anchorage","carrier_route":"C024","congressional_district":"AL","rdi":"Commercial","elot_sequence":"0106","elot_sort":"D","latitude":61.18135,"longitude":-149.83548,"precision":"Zip9","time_zone":"Alaska","utc_offset":-9.0,"dst":true},"analysis":{"dpv_match_code":"Y","dpv_footnotes":"AABB","dpv_cmra":"N","dpv_vacant":"N","active":"Y","footnotes":"N#"}}]'
      {
        'city=orlando&state=fl&street=100%20lake%20hart%20dr.&zipcode=32832' => '[]',
        'city=springfield&state=il&street=1025%20south%206th%20street&zipcode=62703' => '[]',
        'city=richmond&state=va&street=7229%20forest%20avenue%20%23208&zipcode=23226' => richmond_smarty,
        'city=richmond&state=va&street=7229%20forest%20ave.&street2=apt%20208&zipcode=23226' => richmond_smarty,
        'city=richmond&state=va&street=7229%20forest%20ave%20suite%20208&zipcode=23226-3765' => richmond_smarty,
        'city=anchorage&state=ak&street=2421%20east%20tudor%20road%20%23102&zipcode=99507-1166' => anchorage_smary,
        'city=anchorage&state=ak&street=2421%20e.%20tudor%20rd.&street2=apt%20102&zipcode=99507' => anchorage_smary
      }.each do |query, result|
        stub_request(:get, "http://api.smartystreets.com/street-address/?auth-id=&auth-token=&candidates=2&#{query}")
        .to_return(body: result)
      end

      person2 = create(:person, first_name: 'Jane', last_name: 'Doe')
      @contact.people << person2

      @contact.addresses_attributes = [
        { street: '7229 Forest Avenue #208', city: 'Richmond', state: 'VA', postal_code: '23226',
            country: 'United States', location: 'Home', primary_mailing_address: true },
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: false }
      ]
      @contact.save

      g_contact1 = @g_contact
      g_contact2 = GoogleContactsApi::Contact.new(@g_contact, nil, @account.contacts_api_user.api)

      g_contact1['gd$structuredPostalAddress'] = [
        { 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false',
          'gd$street' => { '$t' => "7229 Forest Ave.\nApt 208" }, 'gd$city' => { '$t' => 'Richmond' },
          'gd$region' => { '$t' => 'VA' }, 'gd$postcode' => { '$t' => '23226' },
          'gd$country' => { '$t' => 'United States of America' } },
        { 'rel' => 'http://schemas.google.com/g/2005#other', 'primary' => 'false',
          'gd$street' => { '$t' => '2421 East Tudor Road #102' }, 'gd$city' => { '$t' => 'Anchorage' },
          'gd$region' => { '$t' => 'AK' }, 'gd$postcode' => { '$t' => '99507-1166' },
          'gd$country' => { '$t' => 'United States of America' } },
        { 'rel' => 'http://schemas.google.com/g/2005#work', 'primary' => 'true',
          'gd$street' => { '$t' => '1025 South 6th Street' }, 'gd$city' => { '$t' => 'Springfield' },
          'gd$region' => { '$t' => 'IL' }, 'gd$postcode' => { '$t' => '62703' },
          'gd$country' => { '$t' => 'United States of America' } }
      ]

      g_contact2['gd$structuredPostalAddress'] = [
        { 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false',
          'gd$street' => { '$t' => '7229 Forest Ave Suite 208' }, 'gd$city' => { '$t' => 'Richmond' },
          'gd$region' => { '$t' => 'VA' }, 'gd$postcode' => { '$t' => '23226-3765' },
          'gd$country' => { '$t' => 'United States of America' }
        },
        { 'rel' => 'http://schemas.google.com/g/2005#other', 'primary' => 'true',
          'gd$street' => { '$t' => "2421 E. Tudor Rd.\nApt 102" }, 'gd$city' => { '$t' => 'Anchorage' },
          'gd$region' => { '$t' => 'AK' }, 'gd$postcode' => { '$t' => '99507' },
          'gd$country' => { '$t' => 'United States of America' }
        }
      ]

      @g_contacts = [g_contact1, g_contact2]
      @g_contact_links = [
        build(:google_contact, google_account: @account, person: @person, last_data: { addresses: [] }),
        build(:google_contact, google_account: @account, person: @person2, last_data: { addresses: [] })
      ]
    end

    it 'combines addresses from mpdx and google by master address comparison which uses SmartyStreets' do
      @integrator.sync_addresses(@g_contacts, @contact, @g_contact_links)

      g_contact_addresses = [
        { rel: 'home', primary: false,
          street: "7229 Forest Ave.\nApt 208", city: 'Richmond', region: 'VA', postcode: '23226',
          country: 'United States of America' },
        { rel: 'other', primary: false,
          street: '2421 East Tudor Road #102', city: 'Anchorage', region: 'AK', postcode: '99507-1166',
          country: 'United States of America' },
        { rel: 'work', primary: false,
          street: '1025 South 6th Street', city: 'Springfield', region: 'IL', postcode: '62703',
          country: 'United States of America' },
        { rel: 'work', primary: false,
          street: '100 Lake Hart Dr.', city: 'Orlando', region: 'FL', postcode: '32832',
          country: 'United States of America' }
      ]
      expect(@g_contacts[0].prepped_changes).to eq(addresses: g_contact_addresses)
      expect(@g_contacts[1].prepped_changes).to eq(addresses: g_contact_addresses)

      @contact.reload

      addresses = @contact.addresses.order(:state).map { |address|
        address.attributes.symbolize_keys.slice(:street, :city, :state, :postal_code, :country, :location,
                                                :primary_mailing_address)
      }
      expect(addresses).to eq([
        { street: '7229 Forest Avenue #208', city: 'Richmond', state: 'VA', postal_code: '23226',
          country: 'United States', location: 'Home', primary_mailing_address: true },
        { street: '2421 East Tudor Road #102', city: 'Anchorage', state: 'AK', postal_code: '99507-1166',
          country: 'United States', location: 'Other', primary_mailing_address: false },
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: false },
        { street: '1025 South 6th Street', city: 'Springfield', state: 'IL', postal_code: '62703',
          country: 'United States', location: 'Business', primary_mailing_address: false }
      ])
    end
  end

  describe 'overall first and subsequent sync' do
    it 'combines MPDX & Google data on first sync then propagates updates of email/phone/address on subsequent syncs' do
      setup_first_sync_data
      expect_first_sync_api_put
      @integrator.sync_contacts
      first_sync_expectations

      modify_data
      expect_second_sync_api_put
      @integrator.sync_contacts
      second_sync_expectations
    end

    def setup_first_sync_data
      @g_contact_json_text = File.new(Rails.root.join('spec/fixtures/google_contacts.json')).read
      @api_url = 'https://www.google.com/m8/feeds/contacts'
      stub_request(:get, "#{@api_url}/default/full?alt=json&max-results=100000&q=John%20Doe&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: @g_contact_json_text)

      @updated_g_contact_obj = JSON.parse(@g_contact_json_text)['feed']['entry'][0]
      @updated_g_contact_obj['gd$email'] = [
        { primary: true, rel: 'http://schemas.google.com/g/2005#other', address: 'johnsmith@example.com' },
        { primary: false, rel: 'http://schemas.google.com/g/2005#home', address: 'mpdx@example.com' }
      ]
      @updated_g_contact_obj['gd$phoneNumber'] = [
        { '$t' => '(123) 334-5158', 'rel' => 'http://schemas.google.com/g/2005#mobile', 'primary' => 'true' },
        { '$t' => '(456) 789-0123', 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false' }
      ]
      @updated_g_contact_obj['gd$structuredPostalAddress'] = [
        { 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false',
          'gd$street' => { '$t' => '2345 Long Dr. #232' }, 'gd$city' => { '$t' => 'Somewhere' },
          'gd$region' => { '$t' => 'IL' }, 'gd$postcode' => { '$t' => '12345' },
          'gd$country' => { '$t' => 'United States of America' } },
        { 'gd$country' => { '$t' => 'United States of America' },
          'gd$street' => { '$t' => '123 Big Rd' }, 'gd$city' => { '$t' => 'Anywhere' },
          'gd$region' => { '$t' => 'MO' }, 'gd$postcode' => { '$t' => '56789' } },
        { 'rel' => 'http://schemas.google.com/g/2005#work', 'primary' => 'true',
          'gd$street' => { '$t' => '100 Lake Hart Dr.' }, 'gd$city' => { '$t' => 'Orlando' },
          'gd$region' => { '$t' => 'FL' }, 'gd$postcode' => { '$t' => '32832' },
          'gd$country' => { '$t' => 'United States of America' } }
      ]

      @person.email_address = { email: 'mpdx@example.com', location: 'home', primary: true }
      @person.phone_number = { number: '456-789-0123', primary: true, location: 'home' }

      @contact.addresses_attributes = [
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: true }
      ]
      @contact.save
    end

    def expect_first_sync_api_put
      # Don't test the body of this first sync put as the fisrt sync combine case is already covered by the unit tests
      stub_request(:put, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [@updated_g_contact_obj] }.to_json)
    end

    def first_sync_expectations
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

      expect(@person.phone_numbers.count).to eq(2)
      number1 = @person.phone_numbers.first
      expect(number1.number).to eq('+14567890123')
      expect(number1.location).to eq('home')
      expect(number1.primary).to be_true
      number2 = @person.phone_numbers.last
      expect(number2.number).to eq('+11233345158')
      expect(number2.location).to eq('mobile')
      expect(number2.primary).to be_false

      g_contact_link = @person.google_contacts.first
      expect(g_contact_link.remote_id).to eq('http://www.google.com/m8/feeds/contacts/test.user%40cru.org/base/6b70f8bb0372c')
      expect(g_contact_link.last_etag).to eq('"SXk6cDdXKit7I2A9Wh9VFUgORgE."')

      addresses = @contact.addresses.order(:state).map { |address|
        address.attributes.symbolize_keys.slice(:street, :city, :state, :postal_code, :country, :location,
                                                :primary_mailing_address)
      }
      expect(addresses).to eq([
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: true },
        { street: '2345 Long Dr. #232', city: 'Somewhere', state: 'IL', postal_code: '12345',
          country: 'United States', location: 'Home', primary_mailing_address: false },
        { street: '123 Big Rd', city: 'Anywhere', state: 'MO', postal_code: '56789',
          country: 'United States', location: 'Business', primary_mailing_address: false }
      ])

      last_data = {
        name_prefix: 'Mr',
        given_name: 'John',
        additional_name: 'Henry',
        family_name: 'Doe',
        name_suffix: 'III',
        content: 'Notes here',
        emails: [{ primary: true, rel: 'other', address: 'johnsmith@example.com' },
                 { primary: false, rel: 'home', address: 'mpdx@example.com' }],
        phone_numbers: [
          { number: '(123) 334-5158', rel: 'mobile', primary: true },
          { number: '(456) 789-0123', rel: 'home', primary: false }
        ],
        addresses: [
          { rel: 'home', primary: false, country: 'United States of America',
            city: 'Somewhere', street: '2345 Long Dr. #232', region: 'IL', postcode: '12345' },
          { country: 'United States of America',
            city: 'Anywhere', street: '123 Big Rd', region: 'MO', postcode: '56789', rel: 'work', primary: false },
          { rel: 'work', primary: true,
            street: '100 Lake Hart Dr.', city: 'Orlando', region: 'FL', postcode: '32832',
            country: 'United States of America' }
        ],
        organizations: [{ org_title: 'Worker Person', org_name: 'Example, Inc', rel: 'other', primary: false }],
        websites: [{ href: 'blog.example.com', rel: 'blog', primary: false },
                   { href: 'www.example.com', rel: 'profile', primary: true }]
      }
      expect(g_contact_link.last_data).to eq(last_data)
    end

    def modify_data
      old_email = @person.email_addresses.first
      @person.email_address = { email: 'mpdx_MODIFIED@example.com', primary: true, _destroy: 1, id: old_email.id }

      first_number = @person.phone_numbers.first
      first_number.number = '+14567894444'
      first_number.save

      first_address = @contact.addresses.first
      first_address.street = 'MODIFIED 100 Lake Hart Dr.'
      first_address.save

      @account_list.reload

      WebMock.reset!

      stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

      @updated_g_contact_obj = JSON.parse(@g_contact_json_text)['feed']['entry'][0]
      @updated_g_contact_obj['gd$email'] = [
        { primary: true, rel: 'http://schemas.google.com/g/2005#other', address: 'johnsmith_MODIFIED@example.com' },
        { primary: false, rel: 'http://schemas.google.com/g/2005#home', address: 'mpdx@example.com' }
      ]
      @updated_g_contact_obj['gd$phoneNumber'] = [
        { '$t' => '(123) 334-5555', 'rel' => 'http://schemas.google.com/g/2005#mobile', 'primary' => 'true' },
        { '$t' => '(456) 789-0123', 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false' }
      ]
      @updated_g_contact_obj['gd$structuredPostalAddress'] = [
        { 'rel' => 'http://schemas.google.com/g/2005#home', 'primary' => 'false',
          'gd$street' => { '$t' => '2345 Long Dr. #232' }, 'gd$city' => { '$t' => 'Somewhere' },
          'gd$region' => { '$t' => 'IL' }, 'gd$postcode' => { '$t' => '12345' },
          'gd$country' => { '$t' => 'United States of America' } },
        { 'gd$street' => { '$t' => 'MODIFIED 123 Big Rd' }, 'gd$city' => { '$t' => 'Anywhere' },
          'gd$region' => { '$t' => 'MO' }, 'gd$postcode' => { '$t' => '56789' },
          'gd$country' => { '$t' => 'United States of America' } },
        { 'rel' => 'http://schemas.google.com/g/2005#work', 'primary' => 'true',
          'gd$street' => { '$t' => '100 Lake Hart Dr.' }, 'gd$city' => { '$t' => 'Orlando' },
          'gd$region' => { '$t' => 'FL' }, 'gd$postcode' => { '$t' => '32832' },
          'gd$country' => { '$t' => 'United States of America' } }
      ]
      stub_request(:get, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [@updated_g_contact_obj] }.to_json)
    end

    def expect_second_sync_api_put
      put_xml_regex_str = '</atom:content>\s+'\
        '<gd:email\s+rel="http://schemas.google.com/g/2005#other"\s+primary="true"\s+address="johnsmith_MODIFIED@example.com"/>\s+'\
        '<gd:email\s+rel="http://schemas.google.com/g/2005#home"\s+address="mpdx_MODIFIED@example.com"/>\s+'\
        '<gd:phoneNumber\s+rel="http://schemas.google.com/g/2005#mobile"\s+primary="true"\s+>\(123\) 334-5555</gd:phoneNumber>\s+'\
        '<gd:phoneNumber\s+rel="http://schemas.google.com/g/2005#home"\s+>\(456\) 789-4444</gd:phoneNumber>\s+'\
        '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#home"\s+>\s+'\
          '<gd:city>Somewhere</gd:city>\s+'\
          '<gd:street>2345 Long Dr. #232</gd:street>\s+'\
          '<gd:region>IL</gd:region>\s+'\
          '<gd:postcode>12345</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
        '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#work"\s+>\s+'\
          '<gd:city>Anywhere</gd:city>\s+'\
          '<gd:street>MODIFIED 123 Big Rd</gd:street>\s+'\
          '<gd:region>MO</gd:region>\s+'\
          '<gd:postcode>56789</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
          '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#work"\s+primary="true">\s+'\
          '<gd:city>Orlando</gd:city>\s+'\
          '<gd:street>MODIFIED 100 Lake Hart Dr.</gd:street>\s+'\
          '<gd:region>FL</gd:region>\s+'\
          '<gd:postcode>32832</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
        '<gd:organization'
      stub_request(:put, "#{@api_url}/test.user@cru.org/base/6b70f8bb0372c?alt=json&v=3")
        .with(body: /#{put_xml_regex_str}/m, headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: { 'entry' => [@updated_g_contact_obj] }.to_json)
    end

    def second_sync_expectations
      @person.reload
      expect(@person.email_addresses.count).to eq(2)
      expect(@person.email_addresses.first.email).to eq('mpdx_MODIFIED@example.com')
      expect(@person.email_addresses.last.email).to eq('johnsmith_MODIFIED@example.com')

      expect(@person.phone_numbers.count).to eq(2)
      expect(@person.phone_numbers.first.number).to eq('+14567894444')
      expect(@person.phone_numbers.last.number).to eq('+11233345555')

      addresses = @contact.addresses.order(:state).map { |address|
        address.attributes.symbolize_keys.slice(:street, :city, :state, :postal_code, :country, :location,
                                                :primary_mailing_address)
      }
      expect(addresses).to eq([
        { street: 'MODIFIED 100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: true },
        { street: '2345 Long Dr. #232', city: 'Somewhere', state: 'IL', postal_code: '12345',
          country: 'United States', location: 'Home', primary_mailing_address: false },
        { street: 'MODIFIED 123 Big Rd', city: 'Anywhere', state: 'MO', postal_code: '56789',
          country: 'United States', location: 'Business', primary_mailing_address: false }
      ])
    end
  end
end
