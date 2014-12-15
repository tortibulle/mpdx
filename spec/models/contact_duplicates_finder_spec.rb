require 'spec_helper'

describe ContactDuplicatesFinder do
  let(:account_list) { create(:account_list) }
  let(:dups_finder) { ContactDuplicatesFinder.new(account_list) }

  let(:john_doe1) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_doe2) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_contact1) { create(:contact, name: 'Doe, John 1', account_list: account_list) }
  let(:john_contact2) { create(:contact, name: 'Doe, John 2', account_list: account_list) }

  before do
    john_contact1.people << john_doe1
    john_contact2.people << john_doe2
  end

  describe 'find_duplicate_contacts' do
    it 'finds duplicate contacts who share a person with a common full name' do
      contact_dups = dups_finder.find_duplicate_contacts
      expect(contact_dups.size).to eq(1)
      contact_dup_set = contact_dups.first
      expect(contact_dup_set.size).to eq(2)
      expect(contact_dup_set).to include(john_contact1)
      expect(contact_dup_set).to include(john_contact2)
    end

    it 'does not find duplicates if a contact is marked as not duplicated with the other' do
      john_contact1.update_column(:not_duplicated_with, john_contact2.id)
      expect(dups_finder.find_duplicate_contacts).to eq([])
    end
  end

  describe '#dup_people_by_same_name' do
    it 'finds duplicates with exactly matching name' do
      dups = dups_finder.dup_people_by_same_name
      expect(dups.size).to eq(1)
      dup_id_pair = dups.first.split(',')
      expect(dup_id_pair).to include(john_doe1.id.to_s)
      expect(dup_id_pair).to include(john_doe2.id.to_s)
    end
  end
end
