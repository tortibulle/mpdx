require 'spec_helper'

describe AddressMethods do
  let(:contact) { create(:contact) }
  let(:donor_account) { create(:donor_account) }

  def expect_merge_addresses_works(addressable)
    address1 = create(:address, street: '1 Way', master_address_id: 1)
    address2 = create(:address, street: '1 Way', master_address_id: 1)
    address3 = create(:address, street: '2 Way', master_address_id: 2)
    addressable.addresses << address1
    addressable.addresses << address2
    addressable.addresses << address3

    expect {
      addressable.merge_addresses

    }.to change(Address, :count).from(3).to(2)

    expect(Address.find_by_id(address1.id)).to be_nil
    expect(Address.find_by_id(address2.id)).to eq(address2)
    expect(Address.find_by_id(address3.id)).to eq(address3)
  end

  describe '#merge_addresses' do
    it 'works for contact' do
      expect_merge_addresses_works(contact)
    end

    it 'works for donor_account' do
      expect_merge_addresses_works(donor_account)
    end
  end
end
