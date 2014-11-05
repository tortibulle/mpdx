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

    it 'filters by person name on wildcard search with and without comma' do
      c = create(:contact, name: 'Doe, John')
      p = create(:person, first_name: 'John', last_name: 'Doe')
      c.people << p
      expect(ContactFilter.new(wildcard_search: 'john doe').filter(Contact)).to include c
      expect(ContactFilter.new(wildcard_search: ' Doe,  John ').filter(Contact)).to include c
    end

    it 'does not cause an error if wildcard search less than two words do' do
      expect { ContactFilter.new(wildcard_search: 'john').filter(Contact) }.to_not raise_error
      expect { ContactFilter.new(wildcard_search: '').filter(Contact) }.to_not raise_error
    end
  end
end
