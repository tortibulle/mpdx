require 'spec_helper'

describe GoogleContactsIntegrator do
  before do
    stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

    @user = create(:user)
    @google_account = create(:google_account, person_id: @user.id)
    @account_list = create(:account_list, creator: @user)
    @integration = create(:google_integration, google_account: @google_account, account_list: @account_list,
                                               contacts_integration: true, calendar_integration: false)
    @integrator = GoogleContactsIntegrator.new(@integration)

    @contact = create(:contact, account_list: @account_list, status: 'Partner - Pray', notes: 'about')
    @contact.addresses_attributes = [
      { street: '2 Ln', city: 'City', state: 'MO', postal_code: '23456', country: 'United States', location: 'Business',
        primary_mailing_address: true },
      { street: '1 Way', city: 'Town', state: 'IL', postal_code: '12345', country: 'United States', location: 'Home',
        primary_mailing_address: false }
    ]
    @contact.save

    @person = create(:person, last_name: 'Doe', middle_name: 'Henry', title: 'Mr', suffix: 'III',
                              occupation: 'Worker', employer: 'Company, Inc')

    @person.email_address = { email: 'home@example.com', location: 'home', primary: true }
    @person.email_address = { email: 'john@example.com', location: 'work', primary: false }

    @person.phone_number = { number: '+12223334444', location: 'mobile', primary: true }
    @person.phone_number = { number: '+15552224444', location: 'home', primary: false }

    @person.websites << Person::Website.create(url: 'blog.example.com', primary: true)
    @person.websites << Person::Website.create(url: 'www.example.com', primary: false)

    @contact.people << @person
  end

  it 'doesn\'t export inactive contacts' do
    @contact.update_column(:status, 'Not Interested')
    expect(@google_account.contacts_api_user).to_not receive(:create_contact)
    @integrator.sync_contacts
  end

  it 'creates a new google contact for an active contact' do
    g_contact_attrs = {
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
      websites: [
        { href: 'blog.example.com', primary: true,  rel: 'other' },
        { href: 'www.example.com', primary: false, rel: 'other' }
      ],
      addresses: [
        { rel: 'work', primary: true,  street: '2 Ln', city: 'City', region: 'MO', postcode: '23456',
          country: 'United States of America' },
        { rel: 'home', primary: false,  street: '1 Way', city: 'Town', region: 'IL', postcode: '12345',
          country: 'United States of America' }
      ]
    }
    expect(@google_account.contacts_api_user).to receive(:create_contact).exactly(1)
                                                 .times.and_return(double(id: '1')) do |arg|
      arg.each do |k, v|
        if v.is_a?(Array)
          expect(arg[k].to_set).to eq(g_contact_attrs[k].to_set)
        else
          expect(arg[k]).to eq(g_contact_attrs[k])
        end
      end
    end

    @integrator.sync_contacts

    expect(@person.google_contacts.count).to eq(1)
    google_contact = @person.google_contacts.first
    expect(google_contact.remote_id).to eq('1')
  end

  it 'doesn\'t create a contact if the person is matched to one already' do
    create(:google_contact, person: @person, remote_id: '1', google_account: @google_account)

    expect(@google_account.contacts_api_user).to_not receive(:create_contact)
    @integrator.sync_contacts
  end

  it 'creates a contact if person matched to a different google account' do
    other_google_account = create(:google_account)
    create(:google_contact, person: @person, remote_id: '1', google_account: other_google_account)
    expect(@google_account.contacts_api_user).to receive(:create_contact).and_return(double(id: '1'))
    @integrator.sync_contacts
  end
end
