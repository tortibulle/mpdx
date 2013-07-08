require 'spec_helper'

describe Contact do
  let(:contact) { create(:contact) }

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
    let(:loser_contact) { create(:contact) }

    it "should move all people" do
      contact.people << create(:person)
      contact.people << create(:person, first_name: "Jill")

      loser_contact.people << create(:person, first_name: "Bob")

      contact.merge(loser_contact)
      contact.contact_people.size.should == 3
    end

    it "should move loser's tasks" do
      task = create(:task, account_list: contact.account_list, subject: "Loser task")
      loser_contact.tasks << task

      contact.tasks << create(:task, account_list: contact.account_list, subject: "Winner task")

      shared_task = create(:task, account_list: contact.account_list, subject: "Shared Task")
      contact.tasks << shared_task
      loser_contact.tasks << shared_task

      contact.merge(loser_contact)

      contact.tasks.should include(task, shared_task)
      shared_task.contacts.should match_array [contact]
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

  end

end
