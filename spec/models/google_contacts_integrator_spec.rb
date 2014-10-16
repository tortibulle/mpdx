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

  # describe 'create_or_update_g_contact' do
  #   before do
  #     @g_contact_id = 'http://www.google.com/m8/feeds/contacts/test.user%40cru.org/base/6b70f8bb0372c'
  #     @batch_url = 'https://www.google.com/m8/feeds/contacts/default/full/batch?alt=&v=3'
  #     @g_contact = GoogleContactsApi::Contact.new(
  #       'gd$etag' => 'a', 'id' => { '$t' => @g_contact_id }, 'gd$name' => { 'gd$givenName' => { '$t' => 'John' } }
  #     )
  #     @g_contact.prep_changes(family_name: 'Doe')
  #     @integrator.assigned_remote_ids = [].to_set
  #
  #     @g_contact_response_body = <<-EOS
  #       <feed>
  #         <entry>
  #           <batch:id>0</batch:id>
  #           <batch:status code='200' reason='Success'/>
  #           <id>#{@g_contact_id}</id>
  #         </entry>
  #       </feed>
  #     EOS
  #
  #     @g_contact_link = build(:google_contact, last_data: {})
  #   end
  #
  #   it 'handles the case when the Google auth token needs to be refreshed and can be' do
  #     @account.expires_at = 1.hour.ago
  #     stub_request(:post, @batch_url).to_return(body: @g_contact_response_body)
  #
  #     stub_request(:post, 'https://accounts.google.com/o/oauth2/token').to_return(body: '{"access_token":"t"}')
  #
  #     @integrator.create_or_update_g_contact(@g_contact, @g_contact_link)
  #     expect(@integrator.assigned_remote_ids).to eq([@g_contact_id].to_set)
  #   end
  #
  #   it 'handles the case when the Google auth token cannot be refreshed' do
  #     @account.expires_at = 1.hour.ago
  #
  #     expect_any_instance_of(Person::GoogleAccount).to receive(:contacts_api_user).at_least(1).times.and_return(false)
  #     expect { @integrator.create_or_update_g_contact(@g_contact, @g_contact_link) }
  #       .to raise_error(Person::GoogleAccount::MissingRefreshToken)
  #   end
  #
  #   describe 'retries if Google api returns an error response initially' do
  #     def test_retry_on_error(status)
  #       stub_request(:post, @batch_url).to_return(status: status)
  #         .then.to_return(body: @g_contact_response_body)
  #       expect(@integrator).to receive(:sleep).with(GoogleContactsIntegrator::RETRY_DELAY)
  #       @integrator.create_or_update_g_contact(@g_contact, @g_contact_link)
  #       expect(@integrator.assigned_remote_ids).to eq([@g_contact_id].to_set)
  #     end
  #
  #     it 'for error 500' do
  #       test_retry_on_error(500)
  #     end
  #
  #     it 'for error 502' do
  #       test_retry_on_error(502)
  #     end
  #   end
  #
  #   it 'fails if Google API returns 500 error multiple times' do
  #     expect(@integrator).to receive(:sleep).with(GoogleContactsIntegrator::RETRY_DELAY)
  #     stub_request(:post, @batch_url).to_return(status: 500)
  #     expect { @integrator.create_or_update_g_contact(@g_contact, @g_contact_link) }.to raise_error
  #   end
  # end

  describe 'sync_contacts' do
    it 'syncs contacts and records last synced time' do
      expect(@integrator).to receive(:contacts_to_sync).and_return(['contact'])
      expect(@integrator).to receive(:sync_contact).with('contact')

      now = Time.now
      expect(Time).to receive(:now).at_least(:once).and_return(now)

      @integrator.sync_contacts

      expect(@integration.contacts_last_synced).to eq(now)
    end

    it 'does not re-raise a missing refresh token error' do
      expect_any_instance_of(Person::GoogleAccount).to receive(:contacts_api_user).at_least(1).times.and_return(false)
      expect { @integrator.sync_contacts }.not_to raise_error
    end
  end

  describe 'contacts_to_sync' do
    it 'returns all active contacts if not synced yet' do
      expect(@integration.account_list).to receive(:active_contacts).and_return(['contact'])
      expect(@account.contacts_api_user).to receive(:contacts).and_return(['g_contact'])
      expect(@integrator).to receive(:cache_g_contacts).with(['g_contact'], true)

      expect(@integrator.contacts_to_sync).to eq(['contact'])
    end

    it 'returns queried contacts for subsequent sync' do
      now = Time.now
      @integration.update_column(:contacts_last_synced, now)
      g_contact = double(id: 'id_1', given_name: 'John', family_name: 'Doe')
      expect(@account.contacts_api_user).to receive(:contacts_updated_min).with(now).and_return([g_contact])

      expect(@integrator).to receive(:contacts_to_sync_query).with(['id_1']).and_return(['contact'])
      expect(@integrator).to receive(:cache_g_contacts).with([g_contact], false)

      expect(@integrator.contacts_to_sync).to eq(['contact'])
    end
  end

  describe 'contacts_to_sync_query' do
    before do
      @g_contact = create(:google_contact, google_account: @account, person: @person)
    end

    def contacts_to_sync_query(updated_remote_ids = [])
      @integrator.contacts_to_sync_query(updated_remote_ids).reload.to_a
    end

    def expect_contact_sync_query(result)
      expect(contacts_to_sync_query).to eq(result)
    end

    it 'returns active contacts and not inactive' do
      expect_contact_sync_query([@contact])

      @contact.update_column(:status, 'Not Interested')
      expect_contact_sync_query([])
    end

    it 'only returns contacts that have been modified since last sync' do
      @g_contact.update_column(:last_synced, 1.hour.since)
      expect_contact_sync_query([])

      @g_contact.update_column(:last_synced, 1.year.ago)
      expect_contact_sync_query([@contact])
    end

    it 'detects modification of addresses, people, emails, phone numbers and websites' do
      @g_contact.update_column(:last_synced, 1.hour.since)
      expect_contact_sync_query([])

      # Addresses
      @contact.addresses_attributes = [{ street: '1 Way' }]
      @contact.save
      expect_contact_sync_query([])
      @contact.addresses.first.update_column(:updated_at, 2.hours.since)
      expect_contact_sync_query([@contact])
      @contact.addresses.first.update_column(:updated_at, Time.now)
      expect_contact_sync_query([])

      # People
      @person.update_column(:updated_at, 2.hours.since)
      expect_contact_sync_query([@contact])
      @person.update_column(:updated_at, Time.now)
      expect_contact_sync_query([])

      # Email
      @person.email = 'test@example.com'
      @person.save
      expect_contact_sync_query([])
      @person.email_addresses.first.update_column(:updated_at, 2.hours.since)
      expect_contact_sync_query([@contact])
      @person.email_addresses.first.update_column(:updated_at, Time.now)
      expect_contact_sync_query([])

      # Phone
      @person.phone = '123-456-7890'
      @person.save
      expect(contacts_to_sync_query).to eq([])
      @person.phone_numbers.first.update_column(:updated_at, 2.hours.since)
      expect(contacts_to_sync_query).to eq([@contact])
      @person.phone_numbers.first.update_column(:updated_at, Time.now)
      expect(contacts_to_sync_query).to eq([])

      # Website
      @person.websites << Person::Website.new(url: 'example.com')
      @person.save
      expect(contacts_to_sync_query).to eq([])
      @person.websites.first.update_column(:updated_at, 2.hours.since)
      expect(contacts_to_sync_query).to eq([@contact])
      @person.websites.first.update_column(:updated_at, Time.now)
      expect(contacts_to_sync_query).to eq([])
    end

    it 'finds contacts whose google_contacts records match specified remotely updated ids' do
      @g_contact.update_column(:last_synced, 1.hour.since)
      @g_contact.update_column(:remote_id, 'a')
      expect(contacts_to_sync_query([])).to eq([])
      expect(contacts_to_sync_query(['a'])).to eq([@contact])
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
    before do
      @api_user = @account.contacts_api_user
    end

    it 'calls the api if there are no cached contacts' do
      expect(@api_user).to receive(:get_contact).with('id').and_return('g_contact')
      expect(@integrator.get_g_contact('id')).to eq('g_contact')
    end

    it 'uses the cache if there is a matching cached contact' do
      g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
      @integrator.cache_g_contacts([g_contact], false)
      expect(@api_user).to receive(:get_contact).exactly(0).times
      expect(@integrator.get_g_contact('id')).to eq(g_contact)
    end

    it 'calls the api if there is no matching cached contact' do
      g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
      @integrator.cache_g_contacts([g_contact], false)
      expect(@api_user).to receive(:get_contact).with('non-cached-id').and_return('api_g_contact')
      expect(@integrator.get_g_contact('non-cached-id')).to eq('api_g_contact')
    end

    it 'calls the api if the cache is cleared' do
      g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
      @integrator.cache_g_contacts([g_contact], false)
      @integrator.clear_g_contact_cache

      expect(@api_user).to receive(:get_contact).with('id').and_return('api_g_contact')
      expect(@integrator.get_g_contact('id')).to eq('api_g_contact')
    end
  end

  describe 'query_g_contact' do
    before do
      @api_user = @account.contacts_api_user
      @integrator.assigned_remote_ids = [].to_set
    end

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
      g_contact = double(given_name: 'John', family_name: 'Doe', id: '1')
      expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([g_contact])
      expect(@integrator.query_g_contact(@person)).to eq(g_contact)
    end

    it 'uses the cache if there is a matching cached contact' do
      g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
      @integrator.cache_g_contacts([g_contact], false)

      expect(@api_user).to receive(:query_contacts).exactly(0).times
      expect(@integrator.query_g_contact(@person)).to eq(g_contact)
    end

    it 'calls the api if there is no matching cached contact, and not all g_contacts are cached' do
      cached_g_contact = double(id: 'id', given_name: 'Not-John', family_name: 'Not-Doe')
      @integrator.cache_g_contacts([cached_g_contact], false)

      api_g_contact =  double(id: 'api_id', given_name: 'John', family_name: 'Doe')
      expect(@api_user).to receive(:query_contacts).with('John Doe').and_return([api_g_contact])
      expect(@integrator.query_g_contact(@person)).to eq(api_g_contact)
    end

    it "doesn't call the api if there is no matching cached contact and we specified that all g_contacts are cached" do
      cached_g_contact = double(id: 'id', given_name: 'Not-John', family_name: 'Not-Doe')
      @integrator.cache_g_contacts([cached_g_contact], true)
      expect(@api_user).to receive(:query_contacts).exactly(0).times
      expect(@integrator.query_g_contact(@person)).to be_nil
    end

    it "doesn't return a matching g_contact if that g_contact's remote_id is already assigned" do
      @integrator.assigned_remote_ids = ['already_assigned'].to_set

      g_contact =  double(id: 'already_assigned', given_name: 'John', family_name: 'Doe')
      expect(@integrator).to receive(:lookup_g_contacts_for_name).with('John Doe').and_return([g_contact])
      expect(@integrator.query_g_contact(@person)).to be_nil
    end

    it "doesn't fail if no first or last name" do
      expect(@api_user).to receive(:query_contacts).with(' ').and_return([])
      @person.first_name = nil
      @person.last_name = nil
      expect(@integrator.query_g_contact(@person)).to be_nil
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
      stub_request(:get, "#{@api_url}/default/full?alt=json&max-results=100000&v=3")
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
      @updated_g_contact_obj['gContact$groupMembershipInfo'] = [
        { 'deleted' => 'false', 'href' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/1b9d086d0a95e81a' },
        { 'deleted' => 'false', 'href' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6' },
        { 'deleted' => 'false', 'href' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/33bfe364885eed6f' },
        { 'deleted' => 'false', 'href' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid' }
      ]

      @person.email_address = { email: 'mpdx@example.com', location: 'home', primary: true }
      @person.phone_number = { number: '456-789-0123', primary: true, location: 'home' }
      @person.websites << Person::Website.create(url: 'mpdx.example.com', primary: false)

      @contact.addresses_attributes = [
        { street: '100 Lake Hart Dr.', city: 'Orlando', state: 'FL', postal_code: '32832',
          country: 'United States', location: 'Business', primary_mailing_address: true }
      ]
      @contact.save

      groups_body = {
        'feed' => {
          'entry' => [],
          'openSearch$totalResults' => { '$t' => '0' },
          'openSearch$startIndex' => { '$t' => '0' },
          'openSearch$itemsPerPage' => { '$t' => '0' }
        }
      }
      stub_request(:get, 'https://www.google.com/m8/feeds/groups/default/full?alt=json&max-results=100000&v=2')
        .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: groups_body.to_json)

      create_group_request_regex_str =
        '<atom:entry xmlns:gd="http://schemas.google.com/g/2005" xmlns:atom="http://www.w3.org/2005/Atom">\s*'\
          '<atom:category scheme="http://schemas.google.com/g/2005#kind"\s+term="http://schemas.google.com/contact/2008#group"/>\s*'\
          '<atom:title type="text">MPDx</atom:title>\s*'\
        '</atom:entry>'

      create_group_response = {
        'entry' => {
          'id' => { '$t' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid' }
        }
      }
      stub_request(:post, 'https://www.google.com/m8/feeds/groups/default/full?alt=json&v=3')
        .with(body: /#{create_group_request_regex_str}/m, headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: create_group_response.to_json)
    end

    def expect_first_sync_api_put
      xml_regex_str =
        '<gd:name>\s*'\
          '<gd:namePrefix>Mr</gd:namePrefix>\s*'\
          '<gd:givenName>John</gd:givenName>\s*'\
          '<gd:additionalName>Henry</gd:additionalName>\s*'\
          '<gd:familyName>Doe</gd:familyName>\s*'\
          '<gd:nameSuffix>III</gd:nameSuffix>\s*'\
        '</gd:name>\s*'\
        '<atom:content>about</atom:content>\s*'\
        '<gd:email\s+rel="http://schemas.google.com/g/2005#other"\s+primary="true"\s+address="johnsmith@example.com"/>\s+'\
        '<gd:email\s+rel="http://schemas.google.com/g/2005#home"\s+address="mpdx@example.com"/>\s+'\
        '<gd:phoneNumber\s+rel="http://schemas.google.com/g/2005#mobile"\s+primary="true"\s+>\(123\) 334-5158</gd:phoneNumber>\s+'\
        '<gd:phoneNumber\s+rel="http://schemas.google.com/g/2005#home"\s+>\(456\) 789-0123</gd:phoneNumber>\s+'\
        '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#home"\s+>\s+'\
          '<gd:city>Somewhere</gd:city>\s+'\
          '<gd:street>2345 Long Dr. #232</gd:street>\s+'\
          '<gd:region>IL</gd:region>\s+'\
          '<gd:postcode>12345</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
        '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#work"\s+>\s+'\
          '<gd:city>Anywhere</gd:city>\s+'\
          '<gd:street>123 Big Rd</gd:street>\s+'\
          '<gd:region>MO</gd:region>\s+'\
          '<gd:postcode>56789</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
          '<gd:structuredPostalAddress\s+rel="http://schemas.google.com/g/2005#work"\s+primary="true">\s+'\
          '<gd:city>Orlando</gd:city>\s+'\
          '<gd:street>100 Lake Hart Dr.</gd:street>\s+'\
          '<gd:region>FL</gd:region>\s+'\
          '<gd:postcode>32832</gd:postcode>\s+'\
          '<gd:country>United States of America</gd:country>\s+'\
        '</gd:structuredPostalAddress>\s+'\
        '<gd:organization\s+rel="http://schemas.google.com/g/2005#work"\s+primary="true">\s+'\
          '<gd:orgName>Company, Inc</gd:orgName>\s+'\
          '<gd:orgTitle>Worker</gd:orgTitle>\s+'\
        '</gd:organization>\s+'\
        '<gContact:website\s+href="blog.example.com"\s+rel="blog"\s+/>\s+'\
        '<gContact:website\s+href="www.example.com"\s+rel="profile"\s+primary="true"\s+/>\s+'\
        '<gContact:website\s+href="mpdx.example.com"\s+rel="other"\s+/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/1b9d086d0a95e81a"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/33bfe364885eed6f"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid"/>\s+'
      stub_request(:post, 'https://www.google.com/m8/feeds/contacts/default/full/batch?alt=&v=3')
        .with(body: /#{xml_regex_str}/m, headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: File.new(Rails.root.join('spec/fixtures/google_contacts.xml')).read)
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

      expect(@person.websites.count).to eq(3)
      websites = @person.websites.order(:url).to_a
      expect(websites[0].url).to eq('blog.example.com')
      expect(websites[0].primary).to be_false
      expect(websites[1].url).to eq('mpdx.example.com')
      expect(websites[1].primary).to be_false
      expect(websites[2].url).to eq('www.example.com')
      expect(websites[2].primary).to be_true

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
                   { href: 'www.example.com', rel: 'profile', primary: true }],
        group_memberships: [
          'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/1b9d086d0a95e81a',
          'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6',
          'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/33bfe364885eed6f',
          'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid'
        ],
        deleted_group_memberships: []
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

      website = @person.websites.where(url: 'mpdx.example.com').first
      website.url = 'MODIFIED_mpdx.example.com'
      website.save

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
      @updated_g_contact_obj['gContact$website'] = [
        { 'href' => 'MODIFIED_blog.example.com', 'rel' => 'blog' },
        { 'href' => 'www.example.com', 'rel' => 'profile', 'primary' => 'true' }
      ]

      updated_contacts_body = {
        'feed' => {
          'entry' => [@updated_g_contact_obj],
          'openSearch$totalResults' => { '$t' => '1' },
          'openSearch$startIndex' => { '$t' => '0' },
          'openSearch$itemsPerPage' => { '$t' => '1' }
        }
      }
      formatted_last_sync = GoogleContactsApi::Api.format_time_for_xml(@integration.contacts_last_synced)
      stub_request(:get, "#{@api_url}/default/full?alt=json&max-results=100000&updated-min=#{formatted_last_sync}&v=3")
        .to_return(body: updated_contacts_body.to_json)

      groups_body = {
        'feed' => {
          'entry' => [
            {
              'id' => { '$t' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid' },
              'title' => { '$t' => 'MPDx' }
            }
          ],
          'openSearch$totalResults' => { '$t' => '1' },
          'openSearch$startIndex' => { '$t' => '0' },
          'openSearch$itemsPerPage' => { '$t' => '1' }
        }
      }
      stub_request(:get, 'https://www.google.com/m8/feeds/groups/default/full?alt=json&max-results=100000&v=2')
      .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
      .to_return(body: groups_body.to_json)
    end

    def expect_second_sync_api_put
      xml_regex_str = '</atom:content>\s+'\
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
         '<gd:organization\s+rel="http://schemas.google.com/g/2005#work"\s+primary="true">\s+'\
          '<gd:orgName>Company, Inc</gd:orgName>\s+'\
          '<gd:orgTitle>Worker</gd:orgTitle>\s+'\
        '</gd:organization>\s+'\
        '<gContact:website\s+href="MODIFIED_blog.example.com"\s+rel="blog"\s+/>\s+'\
        '<gContact:website\s+href="www.example.com"\s+rel="profile"\s+primary="true"\s+/>\s+'\
        '<gContact:website\s+href="MODIFIED_mpdx.example.com"\s+rel="other"\s+/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/1b9d086d0a95e81a"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/6"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/33bfe364885eed6f"/>\s+'\
        '<gContact:groupMembershipInfo\s+deleted="false"\s+href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid"/>\s+'\
      '</entry>'
      stub_request(:post, 'https://www.google.com/m8/feeds/contacts/default/full/batch?alt=&v=3')
        .with(body: /#{xml_regex_str}/m, headers: { 'Authorization' => "Bearer #{@account.token}" })
        .to_return(body: File.new(Rails.root.join('spec/fixtures/google_contacts.xml')).read)
    end

    def second_sync_expectations
      @person.reload
      expect(@person.email_addresses.count).to eq(2)
      expect(@person.email_addresses.first.email).to eq('mpdx_MODIFIED@example.com')
      expect(@person.email_addresses.last.email).to eq('johnsmith_MODIFIED@example.com')

      expect(@person.phone_numbers.count).to eq(2)
      expect(@person.phone_numbers.first.number).to eq('+14567894444')
      expect(@person.phone_numbers.last.number).to eq('+11233345555')

      @contact.reload
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

      expect(@person.websites.count).to eq(3)
      websites = @person.websites.order(:url).to_a
      expect(websites[0].url).to eq('MODIFIED_blog.example.com')
      expect(websites[0].primary).to be_false
      expect(websites[1].url).to eq('MODIFIED_mpdx.example.com')
      expect(websites[1].primary).to be_false
      expect(websites[2].url).to eq('www.example.com')
      expect(websites[2].primary).to be_true
    end
  end
end
