require 'spec_helper'

describe DonationSerializer do
  let(:account_list) { create(:account_list) }
  let(:donor_account) { create(:donor_account) }
  let!(:contact) {
    create(:contact, account_list: account_list, name: donor_account.name)
    donor_account.link_to_contact_for(account_list)
  }
  let(:user) { create(:user) }
  let(:donation) { create(:donation, donor_account: donor_account) }
  subject {
    serializer = DonationSerializer.new(donation, scope: { account_list: account_list, user: user })
    serializer.stub(:locale).and_return(:en)
    serializer.as_json[:donation]
  }

  it { should include :amount }
  it { should include :contact_id }
  it { subject[:contact_id].should be contact.id }
  it { should include :donation_date }
end
