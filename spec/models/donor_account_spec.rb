require 'spec_helper'

describe DonorAccount do
  before(:each) do
    @donor_account = create(:donor_account)
  end
  it 'should have one primary_master_person' do
    @mp1 = create(:master_person)
    @donor_account.master_people << @mp1
    @donor_account.primary_master_person.should == @mp1

    -> {
      @donor_account.master_people << create(:master_person)
      @donor_account.primary_master_person.should == @mp1
    }.should_not change(MasterPersonDonorAccount.primary, :count)
  end

  describe 'link_to_contact_for' do
    before do
      @account_list = create(:account_list)
    end
    it 'should return an alreay linked contact' do
      contact = create(:contact, account_list: @account_list)
      contact.donor_accounts << @donor_account
      @donor_account.link_to_contact_for(@account_list).should == contact
    end

    it 'should link a contact based on a matching name' do
      contact = create(:contact, account_list: @account_list, name: @donor_account.name)
      new_contact = @donor_account.link_to_contact_for(@account_list)
      new_contact.should == contact
      new_contact.donor_account_ids.should include(@donor_account.id)
    end

    # This feature was removed
    #it 'should link a contact based on a matching address' do
      #contact = create(:contact, account_list: @account_list)
      #a1 = create(:address, addressable: @donor_account)
      #a2 = create(:address, addressable: contact)
      #new_contact = @donor_account.link_to_contact_for(@account_list)
      #new_contact.should == contact
      #new_contact.donor_account_ids.should include(@donor_account.id)
    #end

    it 'should create a new contact if no match is found' do
      -> {
        @donor_account.link_to_contact_for(@account_list)
      }.should change(Contact, :count)
    end

    it 'should not match to a contact with no addresses' do
      create(:contact, account_list: @account_list)
      create(:address, addressable: @donor_account)
      -> {
        @donor_account.link_to_contact_for(@account_list)
      }.should change(Contact, :count)
    end

  end
end
