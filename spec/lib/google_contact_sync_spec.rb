require 'spec_helper'
require 'google_contact_sync'

describe GoogleContactSync do
  let(:sync) { GoogleContactSync }
  let(:contact) { build(:contact) }
  let(:g_contact_link) { build(:google_contact, last_data: { emails: [], websites: [], phone_numbers: [] }) }
  let(:person) {
    build(:person, last_name: 'Doe', middle_name: 'Henry', title: 'Mr', suffix: 'III', occupation: 'Worker',
          employer: 'Company, Inc')
  }
  let(:g_contact) {
    GoogleContactsApi::Contact.new(
      'gd$etag' => 'a',
      'id' => { '$t' => '1' },
      'gd$name' => { 'gd$givenName' => { '$t' => 'John' }, 'gd$familyName' => { '$t' => 'Doe' } }
    )
  }

  describe 'sync_notes' do
    describe 'first sync' do
      it 'sets blank mpdx notes with google contact notes' do
        g_contact['content'] = { '$t' => 'google notes' }
        contact.notes = ''
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('google notes')
        expect(g_contact.prepped_changes).to eq({})
      end

      it 'sets blank google contact notes to mpdx notes' do
        g_contact['content'] = { '$t' => '' }
        contact.notes = 'mpdx notes'
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('mpdx notes')
        expect(g_contact.prepped_changes).to eq(content: 'mpdx notes')
      end

      it 'prefer mpdx if both are present' do
        g_contact['content'] = { '$t' => 'google notes' }
        contact.notes = 'mpdx notes'
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('mpdx notes')
        expect(g_contact.prepped_changes).to eq(content: 'mpdx notes')
      end

      it 'removes vertical tabs (\v) from both mpdx and google because is an invalid and non-escapable for XML' do
        g_contact['content'] = { '$t' => '' }
        contact.notes = "notes with vertical tab initially then newline: \v"

        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq("notes with vertical tab initially then newline: \n")
        expect(g_contact.prepped_changes).to eq(content: "notes with vertical tab initially then newline: \n")
      end

      it 'handles nil values for MPDX and Google' do
        g_contact['content'] = {}
        contact.notes = nil
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to be_nil
        expect(g_contact.prepped_changes).to eq({})
      end
    end

    describe 'subsequent sync' do
      let(:g_contact_link) { build(:google_contact, last_data: { content: 'old notes' }) }

      it 'sets google to mpdx if only mpdx changed' do
        g_contact['content'] = { '$t' => 'old notes' }
        contact.notes = 'new mpdx notes'
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('new mpdx notes')
        expect(g_contact.prepped_changes).to eq(content: 'new mpdx notes')
      end

      it 'sets mpdx to google if only google changed' do
        g_contact['content'] = { '$t' => 'new google notes' }
        contact.notes = 'old notes'
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('new google notes')
        expect(g_contact.prepped_changes).to eq({})
      end

      it 'sets mpdx to google if both changed' do
        g_contact['content'] = { '$t' => 'new google notes' }
        contact.notes = 'new mpdx notes'
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('new mpdx notes')
        expect(g_contact.prepped_changes).to eq(content: 'new mpdx notes')
      end

      it 'sets google to blank if mpdx changed to blank' do
        g_contact['content'] = { '$t' => 'google notes' }
        contact.notes = ''
        sync.sync_notes(contact, g_contact, g_contact_link)
        expect(contact.notes).to eq('')
        expect(g_contact.prepped_changes).to eq(content: '')
      end
    end
  end

  describe 'sync_basic_person_fields' do
    it 'sets blank mpdx fields with google contact fields' do
      person.update(title: nil, first_name: '', middle_name: nil, last_name: '', suffix: '')
      g_contact['gd$name'] = {
        'gd$namePrefix' => { '$t' => 'Mr' },
        'gd$givenName' => { '$t' => 'John' },
        'gd$additionalName' => { '$t' => 'Henry' },
        'gd$familyName' => { '$t' => 'Doe' },
        'gd$nameSuffix' => { '$t' => 'III' }
      }

      sync.sync_basic_person_fields(person, g_contact, g_contact_link)

      expect(g_contact.prepped_changes).to eq({})

      expect(person.title).to eq('Mr')
      expect(person.first_name).to eq('John')
      expect(person.middle_name).to eq('Henry')
      expect(person.last_name).to eq('Doe')
      expect(person.suffix).to eq('III')
    end

    it 'sets blank google fields to mpdx fields' do
      person.update(title: 'Mr', middle_name: 'Henry', suffix: 'III')
      g_contact['gd$name'] = {}

      sync.sync_basic_person_fields(person, g_contact, g_contact_link)

      expect(g_contact.prepped_changes).to eq(name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry',
                                               family_name: 'Doe', name_suffix: 'III')
    end

    it 'prefers mpdx if both are present' do
      g_contact['gd$name'] = {
        'gd$namePrefix' => { '$t' => 'Not-Mr' },
        'gd$givenName' => { '$t' => 'Not-John' },
        'gd$additionalName' => { '$t' => 'Not-Henry' },
        'gd$familyName' => { '$t' => 'Not-Doe' },
        'gd$nameSuffix' => { '$t' => 'Not-III' }
      }
      person.update(title: 'Mr', middle_name: 'Henry', suffix: 'III')

      sync.sync_basic_person_fields(person, g_contact, g_contact_link)

      expect(g_contact.prepped_changes).to eq(name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry',
                                               family_name: 'Doe', name_suffix: 'III')

      expect(person.title).to eq('Mr')
      expect(person.first_name).to eq('John')
      expect(person.middle_name).to eq('Henry')
      expect(person.last_name).to eq('Doe')
      expect(person.suffix).to eq('III')
    end

    it 'syncs changes between mpdx and google, but prefers mpdx if both changed' do
      g_contact_link = build(:google_contact, last_data: { name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry',
                                           family_name: 'Doe', name_suffix: 'III' })

      g_contact['gd$name'] = {
        'gd$namePrefix' => { '$t' => 'Mr-Google' },
        'gd$givenName' => { '$t' => 'John' },
        'gd$additionalName' => { '$t' => 'Henry' },
        'gd$familyName' => { '$t' => 'Doe-Google' },
        'gd$nameSuffix' => { '$t' => 'III' }
      }
      person.update(title: 'Mr', first_name: 'John-MPDX', middle_name: 'Henry-MPDX', last_name: 'Doe-MPDX', suffix: 'III')

      sync.sync_basic_person_fields(person, g_contact, g_contact_link)

      expect(g_contact.prepped_changes).to eq(given_name: 'John-MPDX', additional_name: 'Henry-MPDX',
                                               family_name: 'Doe-MPDX')

      expect(person.title).to eq('Mr-Google')
      expect(person.first_name).to eq('John-MPDX')
      expect(person.middle_name).to eq('Henry-MPDX')
      expect(person.last_name).to eq('Doe-MPDX')
      expect(person.suffix).to eq('III')
    end
  end

  describe 'sync_employer_and_title' do
    describe 'first sync' do
      it 'sets blank mpdx employer and occupation from google' do
        person.employer = ''
        person.occupation = nil
        g_contact['gd$organization'] = [{ 'gd$orgName' => { '$t' => 'Company' }, 'gd$orgTitle' => { '$t' => 'Worker' } }]

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq({})
        expect(person.employer).to eq('Company')
        expect(person.occupation).to eq('Worker')
      end

      it 'sets blank google employer and occupation from mpdx' do
        person.employer = 'Company'
        person.occupation = 'Worker'
        g_contact['gd$organization'] = []

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq(organizations: [{ org_name: 'Company', org_title: 'Worker',
                                                                   primary: true, rel: 'work' }])
        expect(person.employer).to eq('Company')
        expect(person.occupation).to eq('Worker')
      end

      it 'prefers mpdx if both are present' do
        person.employer = 'Company'
        person.occupation = 'Worker'
        g_contact['gd$organization'] = [{ 'gd$orgName' => { '$t' => 'Not-Company' }, 'gd$orgTitle' => { '$t' => 'Not-Worker' } }]

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq(organizations: [{ org_name: 'Company', org_title: 'Worker',
                                                                   primary: true, rel: 'work' }])
        expect(person.employer).to eq('Company')
        expect(person.occupation).to eq('Worker')
      end
    end

    describe 'subsequent syncs' do
      let(:g_contact_link) {
        build(:google_contact, last_data: { organizations: [{ org_name: 'Old Company', org_title: 'Old Title' }] })
      }

      it 'syncs changes from mpdx to google' do
        person.employer = 'MPDX Company'
        person.occupation = 'MPDX Title'
        g_contact['gd$organization'] = [{ 'gd$orgName' => { '$t' => 'Old Company' }, 'gd$orgTitle' => { '$t' => 'Old Title' } }]

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq(organizations: [{ org_name: 'MPDX Company', org_title: 'MPDX Title',
                                                                   primary: true, rel: 'work' }])
        expect(person.employer).to eq('MPDX Company')
        expect(person.occupation).to eq('MPDX Title')
      end

      it 'syncs changes from google to mpdx' do
        person.employer = 'Old Company'
        person.occupation = 'Old Title'
        g_contact['gd$organization'] = [{ 'gd$orgName' => { '$t' => 'Google Company' }, 'gd$orgTitle' => { '$t' => 'Google Title' } }]

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq({})
        expect(person.employer).to eq('Google Company')
        expect(person.occupation).to eq('Google Title')
      end

      it 'prefers mpdx if both changed' do
        person.employer = 'MPDX Company'
        person.occupation = 'MPDX Title'
        g_contact['gd$organization'] = [{ 'gd$orgName' => { '$t' => 'Gogle Company' }, 'gd$orgTitle' => { '$t' => 'Google Title' } }]

        sync.sync_employer_and_title(person, g_contact, g_contact_link)

        expect(g_contact.prepped_changes).to eq(organizations: [{ org_name: 'MPDX Company', org_title: 'MPDX Title',
                                                                   primary: true, rel: 'work' }])
        expect(person.employer).to eq('MPDX Company')
        expect(person.occupation).to eq('MPDX Title')
      end
    end
  end

  describe 'sync numbers' do
    it 'combines and formats numbers from mpdx and google' do
      person.phone_number = { number: '+12223334444', location: 'mobile', primary: true }

      g_contact.update('gd$phoneNumber' => [
        { '$t' => '(777) 888-9999', 'primary' => 'true', 'rel' => 'http://schemas.google.com/g/2005#other' }
      ])

      sync.sync_numbers(g_contact, person, g_contact_link)

      expect(g_contact.prepped_changes).to eq(phone_numbers: [
        { number: '(777) 888-9999', primary: true, rel: 'other' },
        { number: '(222) 333-4444', primary: false, rel: 'mobile' }
      ])

      person.save

      expect(person.phone_numbers.count).to eq(2)
      phone1 = person.phone_numbers.first
      expect(phone1.number).to eq('+12223334444')
      expect(phone1.location).to eq('mobile')
      expect(phone1.primary).to be_true
      phone2 = person.phone_numbers.last
      expect(phone2.number).to eq('+17778889999')
      expect(phone2.location).to eq('other')
      expect(phone2.primary).to be_false
    end
  end

  describe 'sync addresses' do
    it 'combines addresses from mpdx and google by master address comparison which uses SmartyStreets' do
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

      contact.save!
      person2 = create(:person, first_name: 'Jane', last_name: 'Doe')
      person.save
      contact.people << person
      contact.people << person2

      contact.addresses_attributes = [
        { street: '7229 Forest Avenue #208', city: 'Richmond', state: 'VA', postal_code: '23226',
          country: 'United States', location: 'Home', primary_mailing_address: true },
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: false }
      ]
      contact.save!

      contact.reload
      expect(contact.addresses.where(historic: false).count).to eq(2)

      g_contact1 = g_contact
      g_contact2 = GoogleContactsApi::Contact.new(g_contact, nil, nil)

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

      g_contacts = [g_contact1, g_contact2]
      g_contact_links = [
        build(:google_contact, last_data: { addresses: [] }),
        build(:google_contact, last_data: { addresses: [] })
      ]

      sync.sync_addresses(g_contacts, contact, g_contact_links)

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
      expect(g_contacts[0].prepped_changes).to eq(addresses: g_contact_addresses)
      expect(g_contacts[1].prepped_changes).to eq(addresses: g_contact_addresses)

      contact.reload

      addresses = contact.addresses.order(:state).map { |address|
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

  describe 'sync websites' do
    it 'combines websites from mpdx and google' do
      person.websites << Person::Website.new(url: 'mpdx.example.com', primary: false)
      person.save

      g_contact['gContact$website'] = [{ 'href' => 'google.example.com', 'primary' => 'true', rel: 'blog' }]

      sync.sync_websites(g_contact, person, g_contact_link)

      expect(g_contact.prepped_changes).to eq(websites: [
        { href: 'google.example.com', primary: true, rel: 'blog' },
        { href: 'mpdx.example.com', primary: false, rel: 'other' }
      ])

      expect(person.websites.count).to eq(2)
      websites = person.websites.order(:url).to_a
      expect(websites[0].url).to eq('google.example.com')
      expect(websites[0].primary).to be_true
      expect(websites[1].url).to eq('mpdx.example.com')
      expect(websites[1].primary).to be_false
    end
  end

  describe 'ensure_single_primary_address' do
    it 'sets all but the first primary address in the list to do not primary' do
      address1 = build(:address, primary_mailing_address: true)
      address2 = build(:address, primary_mailing_address: false)
      address3 = build(:address, primary_mailing_address: true)
      sync.ensure_single_primary_address([address1, address2, address3])
      expect(address1.primary_mailing_address).to be_true
      expect(address2.primary_mailing_address).to be_false
      expect(address3.primary_mailing_address).to be_false
    end
  end

  describe 'compare_considering_historic' do
    it "doesn't add or delete historic items in MPDX, doesn't add them to Google, but does delete them from Google" do
      last_sync_list = ['history1']
      mpdx_list = ['history1']
      g_contact_list = ['history2']
      historic_list = %w(history1 history2)

      mpdx_adds, mpdx_dels, g_contact_adds, g_contact_dels =
        sync.compare_considering_historic(last_sync_list, mpdx_list, g_contact_list, historic_list)

      expect(mpdx_adds.to_a).to eq([])
      expect(mpdx_dels.to_a).to eq([])
      expect(g_contact_adds.to_a).to eq([])
      expect(g_contact_dels.to_a).to eq(%w(history1 history2))
    end
  end

  describe 'compare_address_records' do
    it 'uses historic list for comparision' do
      contact.addresses << build(:address, master_address_id: 1, historic: true)
      contact.save
      expect(sync).to receive(:compare_considering_historic).with([], [], [], [1]).and_return([[], [], [], [1], [1]])

      mpdx_adds, mpdx_dels, g_contact_adds, g_contact_dels, g_contact_address_records =
        sync.compare_address_records([], contact, [])

      expect(mpdx_adds.to_a).to eq([])
      expect(mpdx_dels.to_a).to eq([])
      expect(g_contact_adds.to_a).to eq([])
      expect(g_contact_dels.to_a).to eq([1])
      expect(g_contact_address_records.to_a).to eq([])
    end
  end

  describe 'compare_emails_for_sync' do
    it 'uses historic list for comparision' do
      person.email_addresses << build(:email_address, email: 'a@a.co', historic: true)
      person.save!
      expect(sync).to receive(:compare_considering_historic).with([], [], [], ['a@a.co']).and_return('compared')
      expect(sync.compare_emails_for_sync(g_contact, person, g_contact_link)).to eq('compared')
    end
  end

  describe 'g_contact_organizations_for' do
    it 'gives a valid Google contacts organization with primary and rel for an employer and title' do
      expect(sync.g_contact_organizations_for('Company', 'Worker')).to eq([{ org_name: 'Company', org_title: 'Worker',
                                                                             primary: true, rel: 'work' }])
    end

    it 'gives an empty list of both employer and title are blank' do
      expect(sync.g_contact_organizations_for('', nil)).to eq([])
    end
  end
end
