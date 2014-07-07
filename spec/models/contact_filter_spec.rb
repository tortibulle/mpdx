require 'spec_helper'

describe ContactFilter do
  context '#filter' do
    it 'filters contacts with newsletter = Email and state' do
      c = create(:contact, send_newsletter: 'Email')
      a = create(:address, addressable: c)
      p = create(:person)
      c.people << p
      create(:email_address, person: p)
      cf = ContactFilter.new(newsletter: 'email', state: a.state)
      cf.filter(Contact).includes([{ primary_person: [:facebook_account, :primary_picture] },
                                   :tags, :primary_address,
                                   { people: :primary_phone_number }]).should == [c]
    end

    it 'filters contacts with statuses null and another' do
      nil_status = create(:contact, status: nil)
      has_status = create(:contact, status: 'Never Contacted')
      cf = ContactFilter.new(status: ['null', 'Never Contacted'])

      filtered_contacts = cf.filter(Contact)
      filtered_contacts.should include nil_status
      filtered_contacts.should include has_status
    end
  end
end
