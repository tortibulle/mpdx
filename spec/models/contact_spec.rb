require 'spec_helper'

describe Contact do
  let(:account_list) { create(:account_list) }
  let(:contact) { create(:contact, account_list: account_list) }

  describe 'saving addresses' do
    it 'should create an address' do
      address = build(:address, addressable: nil)
      -> {
        contact.addresses_attributes = [address.attributes.with_indifferent_access.except(:id, :addressable_id, :addressable_type, :updated_at, :created_at)]
        contact.save!
      }.should change(Address, :count).by(1)
    end

    it 'should mark an address deleted' do
      address = create(:address, addressable: contact)

      contact.addresses_attributes = [ {id: address.id, _destroy: '1'} ]
      contact.save!

      address.reload.deleted.should == true
    end

    it 'should update an address' do
      stub_request(:get, "http://api.smartystreets.com/street-address/?auth-id=&auth-token=&candidates=2&city=fremont&state=ca&street=123%20somewhere%20stboo&zipcode=94539").
         with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "[]", :headers => {})

      address = create(:address, addressable: contact)
      contact.addresses_attributes = [address.attributes.merge!(street: address.street + 'boo').with_indifferent_access.except(:addressable_id, :addressable_type, :updated_at, :created_at)]
      contact.save!
      contact.addresses.first.street.should == address.street + 'boo'
    end
  end

  describe 'saving donor accounts' do
    it "links to an existing donor account if one matches" do
      donor_account = create(:donor_account)
      contact.donor_accounts_attributes = {'0' => {account_number: donor_account.account_number, organization_id: donor_account.organization_id}}
      contact.save!
      contact.donor_accounts.should include(donor_account)
    end

    it "creates a new donor account" do
      expect {
        contact.donor_accounts_attributes = {'0' => {account_number: 'asdf', organization_id: 1}}
        contact.save!
      }.to change(DonorAccount, :count).by(1)
    end

    it "updates an existing donor account" do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      contact.donor_accounts_attributes = {'0' => {id: donor_account.id, account_number: 'asdf'}}
      contact.save!

      donor_account.reload.account_number.should == 'asdf'
    end

    it "deletes an existing donor account" do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      expect {
        contact.donor_accounts_attributes = {'0' => {id: donor_account.id, account_number: 'asdf', _destroy: '1'}}
        contact.save!
      }.to change(ContactDonorAccount, :count).by(-1)
    end

    it "deletes an existing donor account when posting a blank account number" do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      expect {
        contact.donor_accounts_attributes = {'0' => {id: donor_account.id, account_number: ''}}
        contact.save!
      }.to change(ContactDonorAccount, :count).by(-1)
    end


    it "saves a contact when posting a blank donor account number" do
      contact.donor_accounts_attributes = {'0' => {account_number: '', organization_id: 1}}
      contact.save.should == true
    end

    it "won't let you assign the same donor account number to two contacts" do
      donor_account = create(:donor_account)
      donor_account.contacts << contact

      contact2 = create(:contact, account_list: contact.account_list)
      contact2.update_attributes({donor_accounts_attributes: {'0' => {account_number: donor_account.account_number, organization_id: donor_account.organization_id}}}).should == false
    end



  end

  describe 'create_from_donor_account' do
    before do
      @account_list = create(:account_list)
      @donor_account = create(:donor_account)
    end

    it "should copy the donor account's addresses" do
      create(:address, addressable: @donor_account)
      -> {
        @contact = Contact.create_from_donor_account(@donor_account, @account_list)
      }.should change(Address, :count)
      @contact.addresses.first.should == @donor_account.addresses.first
    end

  end

  it "should have a primary person" do
    person = create(:person)
    contact.people << person
    contact.primary_or_first_person.should == person
  end

  describe 'when being deleted' do
    it "should delete people not linked to another contact" do
      contact.people << create(:person)
      -> {
        contact.destroy
      }.should change(Person, :count)
    end

    it "should NOT delete people linked to another contact" do
      person = create(:person)
      contact.people << person
      contact2 = create(:contact, account_list: contact.account_list)
      contact2.people << person
      -> {
        contact.destroy
      }.should_not change(Person, :count)
    end

    it "deletes associated addresses" do
      create(:address, addressable: contact)
      expect { contact.destroy }
        .to change(Address, :count).by(-1)
    end

  end

  context '#primary_person_id=' do
    it "should not fail if an invalid id is passed in" do
      expect {
        contact.primary_person_id = 0
      }.not_to raise_exception
    end
  end

  describe 'when merging' do
    let(:loser_contact) { create(:contact, account_list: account_list) }

    it "should move all people" do
      contact.people << create(:person)
      contact.people << create(:person, first_name: "Jill")

      loser_contact.people << create(:person, first_name: "Bob")

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
      task = create(:task, account_list: contact.account_list, subject: "Loser task")
      loser_contact.tasks << task

      contact.tasks << create(:task, account_list: contact.account_list, subject: "Winner task")

      shared_task = create(:task, account_list: contact.account_list, subject: "Shared Task")
      contact.tasks << shared_task
      loser_contact.tasks << shared_task

      contact.update_uncompleted_tasks_count
      expect { contact.merge(loser_contact) }
        .to change(contact, :uncompleted_tasks_count).by(1)

      contact.tasks.should include(task, shared_task)
      shared_task.contacts.reload.should match_array [contact]
    end

    it "should not duplicate referrals" do
      referrer = create(:contact)
      loser_contact.referrals_to_me << referrer
      contact.referrals_to_me << referrer

      contact.merge(loser_contact)

      contact.referrals_to_me.length.should == 1
    end

    it "should not remove the facebook account of a person on the merged contact" do
      loser_person = create(:person)
      loser_contact.people << loser_person
      fb = create(:facebook_account, person: loser_person)

      winner_person = create(:person, first_name: loser_person.first_name, last_name: loser_person.last_name)
      contact.people << winner_person

      contact.merge(loser_contact)

      contact.people.length.should == 1

      contact.people.first.facebook_accounts.should == [fb]
    end

    it "should never delete a task" do
      task = create(:task, account_list: account_list)
      loser_contact.tasks << task
      contact.tasks << task
      expect {
      expect {
        contact.merge(loser_contact)
      }.not_to change(Task, :count)
      }.to change(ActivityContact, :count).by(-1)
    end

  end

  context '#destroy' do
    before do
      create(:prayer_letters_account, account_list: account_list)
    end

    it 'deletes this person from prayerletters.com if no other contact has the prayer_letters_id' do
      stub_request(:delete, /www.prayerletters.com\/.*/).
         to_return(:status => 200, :body => "", :headers => {})

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

end
