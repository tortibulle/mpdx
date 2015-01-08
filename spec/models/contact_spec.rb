require 'spec_helper'

describe Contact do
  let(:account_list) { create(:account_list) }
  let(:contact) { create(:contact, account_list: account_list) }

  describe 'saving addresses' do
    it 'should create an address' do
      address = build(:address, addressable: nil)
      expect {
        contact.addresses_attributes = [address.attributes.with_indifferent_access.except(:id, :addressable_id, :addressable_type, :updated_at, :created_at)]
        contact.save!
      }.to change(Address, :count).by(1)
    end

    it 'should mark an address deleted' do
      address = create(:address, addressable: contact)

      contact.addresses_attributes = [{ id: address.id, _destroy: '1' }]
      contact.save!

      expect { address.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'should update an address' do
      stub_request(:get, %r{http:\/\/api\.smartystreets\.com\/street-address})
         .with(headers: { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip, deflate', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
         .to_return(status: 200, body: '[]', headers: {})

      address = create(:address, addressable: contact)
      contact.addresses_attributes = [address.attributes.merge!(street: address.street + 'boo').with_indifferent_access.except(:addressable_id, :addressable_type, :updated_at, :created_at)]
      contact.save!
      contact.addresses.first.street.should == address.street + 'boo'
    end
  end

  describe 'saving email addresses' do
    it 'should change which email address is primary' do
      person = create(:person)
      contact.people << person
      email1 = create(:email_address, primary: true, person: person)
      email2 = create(:email_address, primary: false, person: person)

      people_attributes =
        { 'people_attributes' =>
          { '0' =>
            { 'email_addresses_attributes' =>
              {
                '0' => { 'email' => email1.email, 'primary' => '0', '_destroy' => 'false', 'id' => email1.id },
                '1' => { 'email' => email2.email, 'primary' => '1', '_destroy' => 'false', 'id' => email2.id }
              },
              'id' => person.id
            }
          }
        }
      contact.update_attributes(people_attributes)
      expect(email1.reload.primary?).to be_false
      expect(email2.reload.primary?).to be_true
    end
  end

  describe 'saving donor accounts' do
    it 'links to an existing donor account if one matches' do
      donor_account = create(:donor_account)
      account_list.designation_accounts << create(:designation_account, organization: donor_account.organization)
      contact.donor_accounts_attributes = { '0' => { account_number: donor_account.account_number, organization_id: donor_account.organization_id } }
      contact.save!
      contact.donor_accounts.should include(donor_account)
    end

    it 'creates a new donor account' do
      expect {
        contact.donor_accounts_attributes = { '0' => { account_number: 'asdf', organization_id: create(:organization).id } }
        contact.save!
      }.to change(DonorAccount, :count).by(1)
    end

    it 'updates an existing donor account' do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      contact.donor_accounts_attributes = { '0' => { id: donor_account.id, account_number: 'asdf' } }
      contact.save!

      donor_account.reload.account_number.should == 'asdf'
    end

    it 'deletes an existing donor account' do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      expect {
        contact.donor_accounts_attributes = { '0' => { id: donor_account.id, account_number: 'asdf', _destroy: '1' } }
        contact.save!
      }.to change(ContactDonorAccount, :count).by(-1)
    end

    it 'deletes an existing donor account when posting a blank account number' do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      expect {
        contact.donor_accounts_attributes = { '0' => { id: donor_account.id, account_number: '' } }
        contact.save!
      }.to change(ContactDonorAccount, :count).by(-1)
    end

    it 'saves a contact when posting a blank donor account number' do
      contact.donor_accounts_attributes = { '0' => { account_number: '', organization_id: 1 } }
      contact.save.should == true
    end

    it "won't let you assign the same donor account number to two contacts" do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      contact2 = create(:contact, account_list: contact.account_list)
      contact2.update_attributes(donor_accounts_attributes: { '0' => { account_number: donor_account.account_number, organization_id: donor_account.organization_id } }).should == false
    end

  end

  describe 'create_from_donor_account' do
    before do
      @account_list = create(:account_list)
      @donor_account = create(:donor_account)
    end

    it "should copy the donor account's addresses" do
      create(:address, addressable: @donor_account)
      expect {
        @contact = Contact.create_from_donor_account(@donor_account, @account_list)
      }.to change(Address, :count)
      @contact.addresses.first.equal_to?(@donor_account.addresses.first).should be_true
    end

  end

  it 'should have a primary person' do
    person = create(:person)
    contact.people << person
    contact.primary_or_first_person.should == person
  end

  describe 'when being deleted' do
    it 'should delete people not linked to another contact' do
      contact.people << create(:person)
      expect {
        contact.destroy
      }.to change(Person, :count)
    end

    it 'should NOT delete people linked to another contact' do
      person = create(:person)
      contact.people << person
      contact2 = create(:contact, account_list: contact.account_list)
      contact2.people << person
      expect {
        contact.destroy
      }.to_not change(Person, :count)
    end

    it 'deletes associated addresses' do
      create(:address, addressable: contact)
      expect { contact.destroy }
        .to change(Address, :count).by(-1)
    end
  end

  describe '#late_by?' do
    it 'should tell if a monthly donor is late on their donation' do
      contact.late_by?(2.days, 30.days).should be true
      contact.late_by?(30.days, 60.days).should be false
      contact.late_by?(60.days).should be false
    end

    it 'should tell if an annual donor is late on their donation' do
      contact = create(:contact, pledge_frequency: 12.0, last_donation_date: 14.months.ago)
      contact.late_by?(30.days, 45.days).should be false
      contact.late_by?(45.days).should be true
    end
  end

  context '#primary_person_id=' do
    it 'should not fail if an invalid id is passed in' do
      expect {
        contact.primary_person_id = 0
      }.not_to raise_exception
    end
  end

  describe '#merge' do
    let(:loser_contact) { create(:contact, account_list: account_list) }

    it 'should move all people' do
      contact.people << create(:person)
      contact.people << create(:person, first_name: 'Jill')

      loser_contact.people << create(:person, first_name: 'Bob')

      contact.merge(loser_contact)
      contact.contact_people.size.should == 3
    end

    it 'should not remove the loser from prayer letters service' do
      pla = create(:prayer_letters_account, account_list: account_list)
      pla.should_not_receive(:delete_contact)

      loser_contact.update_column(:prayer_letters_id, 'foo')

      contact.merge(loser_contact)
    end

    it "should move loser's tasks" do
      task = create(:task, account_list: contact.account_list, subject: 'Loser task')
      loser_contact.tasks << task

      contact.tasks << create(:task, account_list: contact.account_list, subject: 'Winner task')

      shared_task = create(:task, account_list: contact.account_list, subject: 'Shared Task')
      contact.tasks << shared_task
      loser_contact.tasks << shared_task

      contact.update_uncompleted_tasks_count
      expect { contact.merge(loser_contact) }
        .to change(contact, :uncompleted_tasks_count).by(1)

      contact.tasks.should include(task, shared_task)
      shared_task.contacts.reload.should match_array [contact]
    end

    it "should move loser's notifications" do
      notification = create(:notification, contact: loser_contact)

      contact.merge(loser_contact)

      contact.notifications.should include(notification)
    end

    it 'should not duplicate referrals' do
      referrer = create(:contact)
      loser_contact.referrals_to_me << referrer
      contact.referrals_to_me << referrer

      contact.merge(loser_contact)

      contact.referrals_to_me.length.should == 1
    end

    it 'should not remove the facebook account of a person on the merged contact' do
      loser_person = create(:person)
      loser_contact.people << loser_person
      fb = create(:facebook_account, person: loser_person)

      winner_person = create(:person, first_name: loser_person.first_name, last_name: loser_person.last_name)
      contact.people << winner_person

      contact.merge(loser_contact)

      contact.people.length.should == 1

      contact.people.first.facebook_accounts.should == [fb]
    end

    it 'should never delete a task' do
      task = create(:task, account_list: account_list)
      loser_contact.tasks << task
      contact.tasks << task
      expect {
        expect {
          contact.merge(loser_contact)
        }.not_to change(Task, :count)
      }.to change(ActivityContact, :count).by(-1)
    end

    it 'prepend notes from loser to winner' do
      loser_contact.notes = 'asdf'
      contact.notes = 'fdsa'
      contact.merge(loser_contact)
      expect(contact.notes).to eq("fdsa\nasdf")
    end

    it 'keeps winner notes if loser has none' do
      loser_contact.notes = nil
      contact.notes = 'fdsa'
      contact.merge(loser_contact)
      expect(contact.notes).to eq('fdsa')
    end

    it 'keeps loser notes if winner has none' do
      loser_contact.notes = 'fdsa'
      contact.notes = ''
      contact.merge(loser_contact)
      expect(contact.notes).to eq('fdsa')
    end

    it 'should total the donations of the contacts' do
      loser_contact.donor_accounts << create(:donor_account, account_number: '1')
      loser_contact.donor_accounts.first.donations << create(:donation, amount: 500.00)
      contact.donor_accounts << create(:donor_account, account_number: '2')
      contact.donor_accounts.first.donations << create(:donation, amount: 300.00)
      contact.merge(loser_contact)
      expect(contact.total_donations).to eq(800.00)
    end

    it 'should keep the least recent first donation date' do
      loser_contact.first_donation_date = '2009-01-01'
      contact.first_donation_date = '2010-01-01'
      contact.merge(loser_contact)
      expect(contact.first_donation_date).to eq(Date.parse('2009-01-01'))
    end

    it 'should keep the most recent last donation date' do
      loser_contact.last_donation_date = '2010-01-01'
      contact.last_donation_date = '2009-01-01'
      contact.merge(loser_contact)
      expect(contact.last_donation_date).to eq(Date.parse('2010-01-01'))
    end
  end

  context '#destroy' do
    before do
      create(:prayer_letters_account, account_list: account_list)
    end

    it 'deletes this person from prayerletters.com if no other contact has the prayer_letters_id' do
      stub_request(:delete, /www.prayerletters.com\/.*/)
        .to_return(status: 200, body: '', headers: {})

      prayer_letters_id  = 'foo'
      contact.prayer_letters_id = prayer_letters_id
      contact.send(:delete_from_prayer_letters)
    end

    it "DOESN'T delete this person from prayerletters.com if another contact has the prayer_letters_id" do
      # This spec passes because no external web call is made
      prayer_letters_id  = 'foo'
      contact.update_column(:prayer_letters_id, prayer_letters_id)
      create(:contact, account_list: account_list, prayer_letters_id: prayer_letters_id)
      contact.send(:delete_from_prayer_letters)
    end
  end

  context 'without set greeting or envelope_greeting' do
    let(:person) { create(:person) }
    let(:spouse) { create(:person, first_name: 'Jill') }

    before do
      contact.people << person
      contact.people << spouse
      contact.name = "#{person.last_name}, #{person.first_name} and #{spouse.first_name}"
      contact.save
      person.save
      spouse.save
    end

    it 'generates a greeting' do
      contact.reload
      expect(contact['greeting']).to be_nil
      expect(contact.greeting).to eq(person.first_name + ' and ' + spouse.first_name)
    end

    it 'excludes deceased person from greetings' do
      person.reload
      person.deceased = true
      person.deceased_check
      person.save
      contact.reload
      expect(contact.greeting).to eq spouse.first_name
      expect(contact.envelope_greeting).to eq(spouse.first_name + ' ' + spouse.last_name)
    end

    it 'excludes deceased spouse from greetings' do
      spouse.reload
      spouse.deceased = true
      spouse.deceased_check
      spouse.save
      contact.reload
      expect(contact.greeting).to eq person.first_name
      expect(contact.envelope_greeting).to eq(person.first_name + ' ' + person.last_name)
    end

    it 'still gives name with single deceased' do
      spouse.destroy
      contact.reload
      expect(contact.people.count).to be 1
      expect(contact.greeting).to eq person.first_name
    end
  end

  context '#envelope_greeting' do
    let(:primary) { create(:person, first_name: 'Bob', last_name: 'Jones', legal_first_name: 'Robert') }

    before do
      contact.update_attributes(greeting: 'Fred and Lori Doe', name: 'Fredrick & Loraine Doe')
      contact.people << primary
    end

    it 'uses contact name' do
      contact.name = 'Smith, John & Jane'
      expect(contact.envelope_greeting).to eq 'John & Jane Smith'
      contact.name = 'John & Jane Smith'
      expect(contact.envelope_greeting).to eq 'John & Jane Smith'
      contact.name = 'Smith,'
      expect(contact.envelope_greeting).to eq 'Smith'
      contact.name = 'Smith, John T and Jane F'
      expect(contact.envelope_greeting).to eq 'John T and Jane F Smith'
      contact.name = 'Doe, John and Jane (Smith)'
      expect(contact.envelope_greeting).to eq 'John Doe and Jane Smith'
      contact.name = 'Doe, John (Jonny) and Jane'
      expect(contact.envelope_greeting).to eq 'John and Jane Doe'
      contact.name = 'New Life Church'
      expect(contact.envelope_greeting).to eq 'New Life Church'
    end

    it 'can be overwriten' do
      spouse = create(:person, first_name: 'Jen', last_name: 'Jones')
      contact.people << spouse
      contact.reload
      expect(contact.envelope_greeting).to eq('Fredrick & Loraine Doe')

      contact.update_attributes(envelope_greeting: 'Mr and Mrs Jones')
      contact.reload
      expect(contact.envelope_greeting).to eq('Mr and Mrs Jones')
    end

    it "will add last name if person doesn't have it set" do
      primary.update_attributes(last_name: '')
      contact.reload
      expect(contact.envelope_greeting).to eq('Fredrick & Loraine Doe')
    end
  end
end
