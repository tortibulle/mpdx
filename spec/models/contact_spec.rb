require 'spec_helper'

describe Contact do
  before(:each) do
    @contact = create(:contact)
  end

  describe 'saving addresses' do
    it 'should create an address' do
      address = build(:address, addressable: nil)
      -> {
        @contact.addresses_attributes = [address.attributes.with_indifferent_access.except(:id, :addressable_id, :addressable_type, :updated_at, :created_at)]
        @contact.save!
      }.should change(Address, :count).by(1)
    end

    it 'should destroy an address' do
      address = create(:address, addressable: @contact)
      -> {
        @contact.addresses_attributes = [ {id: address.id, _destroy: '1'} ]
        @contact.save!
      }.should change(Address, :count).from(1).to(0)
    end

    it 'should update an address' do
      address = create(:address, addressable: @contact)
      @contact.addresses_attributes = [address.attributes.merge!(street: address.street + 'boo').with_indifferent_access.except(:addressable_id, :addressable_type, :updated_at, :created_at)]
      @contact.save!
      @contact.addresses.first.street.should == address.street + 'boo'
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
    @contact.people << person
    @contact.primary_person.should == person
  end

  describe 'when being deleted' do
    it "should delete people not linked to another contact" do
      @contact.people << create(:person)
      -> {
        @contact.destroy
      }.should change(Person, :count)
    end

    it "should NOT delete people linked to another contact" do
      person = create(:person)
      @contact.people << person
      contact2 = create(:contact, account_list: @contact.account_list)
      contact2.people << person
      -> {
        @contact.destroy
      }.should_not change(Person, :count)
    end

  end

end
