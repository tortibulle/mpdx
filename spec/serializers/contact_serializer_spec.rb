require 'spec_helper'

describe ContactSerializer do
  describe "contacts list" do
    let(:contact) {
      c = create(:contact)
      c.addresses << build(:address)
      c
    }
    let(:person) {
      p = build(:person)
      p.email_addresses << build(:email_address)
      p.phone_numbers << build(:phone_number)
      contact.people << p
      p
    }
    let(:json){ ContactSerializer.new(contact).as_json }
    subject{ json[:contact] }

    describe "contact" do
      it { should include :id }
      it { should include :name }
      it { should include :pledge_amount }
      it { should include :pledge_frequency }
      it { should include :status }
      it { should include :notes }
      it { should include :person_ids }
    end

    it "people list" do
      json.should include :people
    end

    it "addresses list" do
      json.should include :addresses
    end

    # it "cache_key is dependant on include params" do
    #   key = ContactSerializer.new(contact, {scope: {include: 'person'}}).cache_key
    #   key.should_not == ContactSerializer.new(contact).cache_key
    # end
    #
    # it "cache_key should change when updated" do
    #   expect{contact.touch}.to change { ContactSerializer.new(contact).cache_key }
    # end
  end
end
