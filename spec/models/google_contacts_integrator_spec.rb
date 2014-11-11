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

    @api_url = 'https://www.google.com/m8/feeds/contacts'
  end

  describe 'sync_contacts basic function' do
    it 'syncs contacts and records last synced time' do
      expect(@integrator).to receive(:setup_assigned_remote_ids)

      expect(@integrator).to receive(:contacts_to_sync).and_return([@contact], [])
      expect(@integrator).to receive(:sync_contact).with(@contact)

      now = Time.now
      expect(Time).to receive(:now).at_least(:once).and_return(now)

      @integrator.sync_contacts

      expect(@integration.contacts_last_synced).to eq(now)
    end

    it 'does not re-raise a missing refresh token error' do
      expect_any_instance_of(Person::GoogleAccount).to receive(:contacts_api_user)
                                                       .and_raise(Person::GoogleAccount::MissingRefreshToken)
      expect { @integrator.sync_contacts }.not_to raise_error
    end
  end

  describe 'contacts_to_sync' do
    before do
      @integrator.cache = GoogleContactsCache.new(@account)
    end

    it 'returns all active contacts if not synced yet' do
      expect(@integration.account_list).to receive(:active_contacts).and_return([@contact])
      expect(@account.contacts_api_user).to receive(:contacts).and_return([@g_contact])

      expect(@integrator.contacts_to_sync).to eq([@contact])
    end

    it 'returns queried contacts for subsequent sync' do
      now = Time.now
      @integration.update_column(:contacts_last_synced, now)
      g_contact = double(id: 'id_1', given_name: 'John', family_name: 'Doe')
      expect(@account.contacts_api_user).to receive(:contacts_updated_min).with(now).and_return([g_contact])

      expect(@integrator).to receive(:contacts_to_sync_query).with([g_contact]).and_return([@contact])
      expect(@integrator.contacts_to_sync).to eq([@contact])
    end
  end

  describe 'mpdx_group' do
    it 'searches for an existing group which matches the goal title, and caches it' do
      mpdx_group = double(title: GoogleContactsIntegrator::CONTACTS_GROUP_TITLE)
      expect(@integrator.api_user).to receive(:groups).exactly(:once).and_return([mpdx_group])
      expect(@integrator.mpdx_group).to eq(mpdx_group)

      # Test a second time to check that it caches it rather than calling the API again
      expect(@integrator.mpdx_group).to eq(mpdx_group)
    end

    it 'creates a group if none match its title do' do
      not_mpdx_group = double(title: 'not-mpdx-group-title')
      mpdx_group = double
      expect(@integrator.api_user).to receive(:groups).exactly(:once).and_return([not_mpdx_group])

      expect(GoogleContactsApi::Group).to receive(:create).exactly(:once)
                                          .with({ title: GoogleContactsIntegrator::CONTACTS_GROUP_TITLE }, @integrator.api_user.api)
                                          .and_return(mpdx_group)

      expect(@integrator.mpdx_group).to eq(mpdx_group)

      # Test a second time to check that it caches it rather than calling the API again
      expect(@integrator.mpdx_group).to eq(mpdx_group)
    end
  end

  describe 'contacts_to_sync_query' do
    before do
      @g_contact = create(:google_contact, google_account: @account, person: @person, contact: @contact)
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

    it 'finds contacts whose remote g_contacts have been updated since the matching google_contacts records' do
      @g_contact.update_column(:last_synced, 1.hour.since)
      @g_contact.update_column(:remote_id, 'a')
      expect(contacts_to_sync_query([])).to eq([])

      previously_updated_g_contact = double(id: 'a', updated: 2.hours.ago)
      expect(contacts_to_sync_query([previously_updated_g_contact])).to eq([])

      since_sync_updated_g_contact = double(id: 'a', updated: 2.hours.since)
      expect(contacts_to_sync_query([since_sync_updated_g_contact])).to eq([@contact])
    end
  end

  describe 'logic for assigning each MPDX contact to a single Google contact' do
    describe 'setup_assigned_remote_ids' do
      it 'queries remote ids for the specific google account and account list' do
        create(:google_contact, remote_id: 'not in account list or google account')
        create(:google_contact, remote_id: 'id', person: @person, contact: @contact, google_account: @account)
        @integrator.setup_assigned_remote_ids
        expect(@integrator.assigned_remote_ids).to eq(['id'].to_set)
      end
    end

    describe 'get_or_query_g_contact' do
      it 'returns nil if a remote id is already assigned' do
        g_contact_link = double(remote_id: nil)
        g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
        @integrator.cache = double
        expect(@integrator.cache).to receive(:select_by_name).with('John', 'Doe').exactly(:twice).and_return([g_contact])

        @integrator.assigned_remote_ids = [].to_set
        expect(@integrator.get_or_query_g_contact(g_contact_link, @person)).to eq(g_contact)

        # Return nil if the id is already taken
        @integrator.assigned_remote_ids = ['id'].to_set
        expect(@integrator.get_or_query_g_contact(g_contact_link, @person)).to be_nil
      end
    end

    describe 'get_g_contact_and_link' do
      it 'marks the remote id of a queried g_contact as assigned and adds the g_contact to the mpdx group' do
        g_contact_link = create(:google_contact, remote_id: 'id', person: @person, contact: @contact,
                                google_account: @account)
        g_contact = double(id: 'id', given_name: 'John', family_name: 'Doe')
        expect(@integrator).to receive(:get_or_query_g_contact).with(g_contact_link, @person).and_return(g_contact)

        mpdx_group = double
        expect(@integrator).to receive(:mpdx_group).and_return(mpdx_group)
        expect(g_contact).to receive(:prep_add_to_group).with(mpdx_group)

        contact_person = @contact.contact_people.first

        @integrator.assigned_remote_ids = [].to_set
        expect(@integrator.get_g_contact_and_link(contact_person)).to eq([g_contact, g_contact_link])
        expect(@integrator.assigned_remote_ids).to eq(['id'].to_set)
      end

      describe 'save_g_contact_links' do
        it 'marks the remote id of a saved g_contact as assigned' do
          g_contact_link = build(:google_contact, remote_id: 'id', person: @person, contact: @contact,
                                  google_account: @account)
          g_contact = double(id: 'id', formatted_attrs: {}, etag: '')

          @integrator.assigned_remote_ids = [].to_set
          @integrator.save_g_contact_links([[g_contact, g_contact_link]])
          expect(@integrator.assigned_remote_ids).to eq(['id'].to_set)
        end
      end
    end
  end

  describe 'sync_contact' do
    it 'does not save a g_contact if it has not changed since the last sync' do
      g_contact_link = double(last_data: { given_name: 'John' })
      g_contact = double(attrs_with_changes:  { given_name: 'John' })

      contact_person = @contact.contact_people.first
      expect(@integrator).to receive(:get_g_contact_and_link).with(contact_person).and_return([g_contact, g_contact_link])
      expect(GoogleContactSync).to receive(:sync_contact).with(@contact, [[g_contact, g_contact_link]])

      expect(@integrator).to receive(:save_g_contact_links).with([[g_contact, g_contact_link]])
      expect(@integrator).to receive(:save_g_contacts_then_links).exactly(0).times

      @integrator.sync_contact(@contact)
    end

    it 'saves the g_contacts if they were modified' do
      g_contact_link = double(last_data: { given_name: 'John' })
      g_contact = double(attrs_with_changes:  { given_name: 'MODIFIED-John' })

      contact_person = @contact.contact_people.first
      expect(@integrator).to receive(:get_g_contact_and_link).with(contact_person).and_return([g_contact, g_contact_link])
      expect(GoogleContactSync).to receive(:sync_contact).with(@contact, [[g_contact, g_contact_link]])

      expect(@integrator).to receive(:save_g_contacts_then_links).with(@contact, [g_contact], [[g_contact, g_contact_link]])

      @integrator.sync_contact(@contact)
    end
  end

  def stub_mpdx_group_request
    groups_body = {
      'feed' => {
        'entry' => [
          {
            'id' => { '$t' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid' },
            'title' => { '$t' => GoogleContactsIntegrator::CONTACTS_GROUP_TITLE }
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

  def empty_feed_json
    {
      'feed' => {
        'entry' => [],
        'openSearch$totalResults' => { '$t' => '0' },
        'openSearch$startIndex' => { '$t' => '0' },
        'openSearch$itemsPerPage' => { '$t' => '0' }
      }
    }.to_json
  end

  def stub_empty_g_contacts
    stub_request(:get, "#{@api_url}/default/full?alt=json&max-results=100000&v=3")
      .with(headers: { 'Authorization' => "Bearer #{@account.token}" })
      .to_return(body: empty_feed_json)
  end

  def stub_empty_updated_g_contacts
    stub_request(:get, %r{#{@api_url}/default/full\?alt=json&max-results=100000&updated-min=.*&v=3})
      .to_return(body: empty_feed_json)
  end

  describe 'overall sync for creating a new google contact' do
    it 'creates a new google contact and association for a contact to sync' do
      stub_empty_g_contacts
      stub_empty_updated_g_contacts
      stub_mpdx_group_request

      contact_name_info = <<-EOS
        <gd:name>
          <gd:namePrefix>Mr</gd:namePrefix>
          <gd:givenName>John</gd:givenName>
          <gd:additionalName>Henry</gd:additionalName>
          <gd:familyName>Doe</gd:familyName>
          <gd:nameSuffix>III</gd:nameSuffix>
        </gd:name>
      EOS

      contact_org_and_group_info = <<-EOS
        <gd:organization rel="http://schemas.google.com/g/2005#work"   primary="true">
          <gd:orgName>Company, Inc</gd:orgName>
          <gd:orgTitle>Worker</gd:orgTitle>
        </gd:organization>
        <gContact:groupMembershipInfo deleted="false" href="http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid"/>
      EOS

      create_contact_request_xml = <<-EOS
      <feed  xmlns='http://www.w3.org/2005/Atom' xmlns:gContact='http://schemas.google.com/contact/2008'
                 xmlns:gd='http://schemas.google.com/g/2005'  xmlns:batch='http://schemas.google.com/gdata/batch'>
        <atom:entry  xmlns:atom="http://www.w3.org/2005/Atom"  xmlns:gd="http://schemas.google.com/g/2005"
                             xmlns:gContact="http://schemas.google.com/contact/2008">
          <atom:category  scheme="http://schemas.google.com/g/2005#kind"
                                     term="http://schemas.google.com/contact/2008#contact"/>
          <batch:id>0</batch:id>
          <batch:operation type="insert"/>
          #{contact_name_info}
          <atom:content>about</atom:content>
          #{contact_org_and_group_info}
        </atom:entry>
      </feed>
      EOS
      create_contact_response_xml = <<-EOS
        <feed gd:etag="&quot;QHg9eDVSLyt7I2A9XRdQE0QORQY.&quot;"
                  xmlns="http://www.w3.org/2005/Atom" xmlns:batch="http://schemas.google.com/gdata/batch"
                  xmlns:gContact="http://schemas.google.com/contact/2008" xmlns:gd="http://schemas.google.com/g/2005"
                  xmlns:openSearch="http://a9.com/-/spec/opensearch/1.1/">
          <entry>
            <batch:id>0</batch:id>
            <batch:operation type='insert'/>
            <batch:status code='201' reason='Created'/>
            #{contact_name_info}
            <content>about</content>
            #{contact_org_and_group_info}
          </entry>
        </feed>
      EOS

      stub_request(:post, 'https://www.google.com/m8/feeds/contacts/default/full/batch?alt=&v=3').to_return do |request|
        expect(EquivalentXml.equivalent?(request.body, create_contact_request_xml)).to be_true
        { body: create_contact_response_xml }
      end

      @integrator.sync_contacts

      @person.reload
      expect(@person.google_contacts.count).to eq(1)
      last_data = {
        name_prefix: 'Mr', given_name: 'John', additional_name: 'Henry', family_name: 'Doe', name_suffix: 'III',
        content: 'about', emails: [], phone_numbers: [], addresses: [],
        organizations: [{ rel: 'work', primary: true, org_name: 'Company, Inc', org_title: 'Worker' }],
        websites: [], group_memberships: ['http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid'],
        deleted_group_memberships: []
      }
      expect(@person.google_contacts.first.last_data).to eq(last_data)
      expect(@person.google_contacts.first.last_synced.nil?).to be_false
    end
  end

  describe 'sync behavior for person in multiple contacts' do
    before do
      @contact2 = create(:contact, name: 'John Doe 2', account_list: @account_list, status: 'Partner - Pray', notes: 'about')
      @contact2.people << @person

      stub_empty_g_contacts
      stub_empty_updated_g_contacts
      stub_mpdx_group_request
    end

    it 'syncs each person-contact with its own Google contact' do
      times_batch_create_or_update_called = 0
      batch_time3_g_contact_id = ''
      expect(@account.contacts_api_user).to receive(:batch_create_or_update).exactly(4).times
                                            .and_return do |g_contact, &block|
        times_batch_create_or_update_called += 1
        case times_batch_create_or_update_called
        when 1
          g_contact['id'] = { '$t' => '1' }
          block.call(code: 201)
        when 2
          g_contact['id'] = { '$t' => '2' }
          block.call(code: 201)
        when 3
          batch_time3_g_contact_id = g_contact.id
          block.call(code: 200)
        when 4
          # On the second sync, expect different ids for the different person-contacts
          expect([g_contact.id, batch_time3_g_contact_id].to_set).to eq(%w(1 2).to_set)
          block.call(code: 200)
        end
      end

      # First sync will have it do creates
      expect(times_batch_create_or_update_called).to eq(0)
      @integrator.sync_contacts
      expect(times_batch_create_or_update_called).to eq(2)

      # Second sync have it do an update
      @person.touch
      g_contact1 = GoogleContactsApi::Contact.new('id' => { '$t' => '1' })
      g_contact2 = GoogleContactsApi::Contact.new('id' => { '$t' => '2' })
      expect(@account.contacts_api_user).to receive(:get_contact).with('1').and_return(g_contact1)
      expect(@account.contacts_api_user).to receive(:get_contact).with('2').and_return(g_contact2)
      @integrator.sync_contacts
      expect(times_batch_create_or_update_called).to eq(4)
    end
  end

  describe 'sync behavior for merged MPDX contacts/people' do
    before do
      @contact.update_column(:notes, 'contact')
      @contact2 = create(:contact, name: 'John Doe 2', account_list: @account_list, status: 'Partner - Pray', notes: 'contact2')
      @contact2.people << @person

      @person2 = create(:person, first_name: 'Jane', last_name: 'Doe')
      @contact.people << @person2
      @contact2.people << @person2

      stub_empty_g_contacts
      stub_empty_updated_g_contacts
      stub_mpdx_group_request
    end

    it 'deletes Google contacts for losing merged contacts/people' do
      g_contact_ids = {}
      g_contacts_for_ids = {}

      batch_create_or_update_calls = 0
      expect(@account.contacts_api_user).to receive(:batch_create_or_update).exactly(7).times
                                            .and_return do |g_contact, &block|
        batch_create_or_update_calls += 1
        case batch_create_or_update_calls
        when 1..4
          g_contact_id = batch_create_or_update_calls.to_s
          g_contact['id'] = { '$t' => g_contact_id }
          g_contact['gd$etag'] = 'etag:' + g_contact_id
          g_contact['content'] = { '$t' =>  g_contact.prepped_changes[:content] }
          g_contact['gd$name'] = { 'gd$givenName' => { '$t' =>  g_contact.prepped_changes[:given_name] } }
          notes_and_first_name = g_contact.content + ':' + g_contact.given_name
          g_contact_ids[notes_and_first_name] = g_contact_id
          g_contacts_for_ids[g_contact_id] = g_contact
          block.call(code: 201)
        else
          block.call(code: 200)
        end
      end

      expect(@account.contacts_api_user).to receive(:get_contact).at_least(:once).and_return { |id| g_contacts_for_ids[id] }

      # The first sync should create four Google contacts for @contact-@person, @contact-@person2,
      # @contact2-@person, and @contact2-@person2
      @integrator.sync_contacts

      expect(batch_create_or_update_calls).to eq(4)
      expect(GoogleContact.all.count).to eq(4)
      expect(GoogleContact.find_by(contact: @contact, person: @person).remote_id).to eq(g_contact_ids['contact:John'])
      expect(GoogleContact.find_by(contact: @contact, person: @person2).remote_id).to eq(g_contact_ids['contact:Jane'])
      expect(GoogleContact.find_by(contact: @contact2, person: @person).remote_id).to eq(g_contact_ids['contact2:John'])
      expect(GoogleContact.find_by(contact: @contact2, person: @person2).remote_id).to eq(g_contact_ids['contact2:Jane'])

      # Then we merge @contact with @contact2 (@contact wins), so we should delete the @contact2 g_contacts
      @contact.merge(@contact2)
      expect(@account.contacts_api_user).to receive(:delete_contact)
                                            .with(g_contact_ids['contact2:John'], 'etag:' + g_contact_ids['contact2:John'])
      expect(@account.contacts_api_user).to receive(:delete_contact)
                                            .with(g_contact_ids['contact2:Jane'], 'etag:' + g_contact_ids['contact2:Jane'])
      @integrator.sync_contacts
      expect(GoogleContact.all.count).to eq(2)
      expect(GoogleContact.find_by(contact: @contact, person: @person).remote_id).to eq(g_contact_ids['contact:John'])
      expect(GoogleContact.find_by(contact: @contact, person: @person2).remote_id).to eq(g_contact_ids['contact:Jane'])

      # Then we merge @person with @person2 (@person wins), so we should delete @person2 g_contact
      @person.merge(@person2)
      expect(@account.contacts_api_user).to receive(:delete_contact)
                                            .with(g_contact_ids['contact:Jane'], 'etag:' + g_contact_ids['contact:Jane'])
      @integrator.sync_contacts
      expect(GoogleContact.all.count).to eq(1)
      expect(GoogleContact.find_by(contact: @contact, person: @person).remote_id).to eq(g_contact_ids['contact:John'])
    end
  end

  describe 'sync behavior for HTTP errors' do
    before do
      stub_mpdx_group_request
      @integration.update_column(:contacts_last_synced, 1.hour.ago)
      create(:google_contact, google_account: @account, contact: @contact, person: @person, remote_id: '1',
             last_data: { given_name: 'John', family_name: 'Doe' }, last_synced: 1.hour.ago)
      expect(@account.contacts_api_user).to receive(:contacts_updated_min).at_least(:once).and_return([])
    end

    it 'retries the sync and creates a new contact on a 404 error' do
      expect(@account.contacts_api_user).to receive(:get_contact).with('1').and_return(@g_contact)
      expect(@account.contacts_api_user).to receive(:query_contacts).with('John Doe').and_return([])

      new_g_contact = GoogleContactsApi::Contact.new
      expect(GoogleContactsApi::Contact).to receive(:new).and_return(new_g_contact)

      times_batch_create_or_update_called = 0

      expect(@account.contacts_api_user).to receive(:batch_create_or_update)
                                            .exactly(2).times.and_return do |g_contact, &block|
        times_batch_create_or_update_called += 1

        case times_batch_create_or_update_called
        when 1
          expect(g_contact).to eq(@g_contact)
          block.call(code: 404)
        when 2
          expect(g_contact).to eq(new_g_contact)
          block.call(code: 201)
        end
      end

      expect(times_batch_create_or_update_called).to eq(0)
      @integrator.sync_contacts
      expect(times_batch_create_or_update_called).to eq(2)
    end

    it 'retries the sync and reloads a contact on a 412 error' do
      g_contact_reloaded = GoogleContactsApi::Contact.new('gd$etag' => 'a', 'id' => { '$t' => '2' },
        'gd$name' => { 'gd$givenName' => { '$t' => 'MODIFIED-Jane' }, 'gd$familyName' => { '$t' => 'Doe' } })
      expect(@account.contacts_api_user).to receive(:get_contact).with('1').exactly(:twice)
                                            .and_return(@g_contact, g_contact_reloaded)

      times_batch_create_or_update_called = 0
      expect(@account.contacts_api_user).to receive(:batch_create_or_update)
                                            .exactly(2).times.and_return do |g_contact, &block|
        times_batch_create_or_update_called += 1

        case times_batch_create_or_update_called
        when 1
          expect(g_contact).to eq(@g_contact)
          block.call(code: 412)
        when 2
          expect(g_contact).to eq(g_contact_reloaded)
          block.call(code: 200)
        end
      end

      expect(times_batch_create_or_update_called).to eq(0)
      @integrator.sync_contacts
      expect(times_batch_create_or_update_called).to eq(2)
    end

    it 'raises an error for 500 errors returned on individual sync' do
      expect(@account.contacts_api_user).to receive(:get_contact).with('1').and_return(@g_contact)

      times_batch_create_or_update_called = 0
      expect(@account.contacts_api_user).to receive(:batch_create_or_update)
                                            .exactly(:once).and_return do |g_contact, &block|
        times_batch_create_or_update_called += 1

        case times_batch_create_or_update_called
        when 1
          expect(g_contact).to eq(@g_contact)
          block.call(code: 500)
        end
      end

      expect(times_batch_create_or_update_called).to eq(0)
      expect { @integrator.sync_contacts }.to raise_error
      expect(times_batch_create_or_update_called).to eq(1)
    end
  end

  describe 'overall first and subsequent sync for modifed contact info' do
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

      stub_empty_updated_g_contacts

      stub_mpdx_group_request

      create_group_request_regex_str =
        '<atom:entry xmlns:gd="http://schemas.google.com/g/2005" xmlns:atom="http://www.w3.org/2005/Atom">\s*'\
          '<atom:category scheme="http://schemas.google.com/g/2005#kind"\s+term="http://schemas.google.com/contact/2008#group"/>\s*'\
          "<atom:title type=\"text\">#{ GoogleContactsIntegrator::CONTACTS_GROUP_TITLE }</atom:title>\s*"\
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

      stub_request(:get, %r{#{@api_url}/default/full\?alt=json&max-results=100000&updated-min=.*&v=3})
        .to_return(body: updated_contacts_body.to_json).then.to_return(body: empty_feed_json)

      groups_body = {
        'feed' => {
          'entry' => [
            {
              'id' => { '$t' => 'http://www.google.com/m8/feeds/groups/test.user%40cru.org/base/mpdxgroupid' },
              'title' => { '$t' => GoogleContactsIntegrator::CONTACTS_GROUP_TITLE }
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
