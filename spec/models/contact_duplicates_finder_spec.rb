require 'spec_helper'

describe ContactDuplicatesFinder do
  let(:account_list) { create(:account_list) }
  let(:dups_finder) { ContactDuplicatesFinder.new(account_list) }

  let(:john_doe1) { create(:person, first_name: 'john', last_name: 'doe') }
  let(:john_doe2) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_contact1) { create(:contact, name: 'Doe, John 1', account_list: account_list) }
  let(:john_contact2) { create(:contact, name: 'Doe, John 2', account_list: account_list) }

  let(:nickname) { create(:nickname, name: 'john', nickname: 'johnny', suggest_duplicates: true) }

  before do
    john_contact1.people << john_doe1
    john_contact2.people << john_doe2
  end

  describe 'dup_contact_sets' do
    it 'finds duplicate contacts given for people with the same name' do
      dups = dups_finder.dup_contact_sets
      expect(dups.size).to eq(1)
      dup = dups.first
      expect(dup.size).to eq(2)
      expect(dup).to include(john_contact1)
      expect(dup).to include(john_contact2)
    end

    it 'does not find duplicates if a contact is marked as not duplicated with the other' do
      john_contact1.update_column(:not_duplicated_with, john_contact2.id)

      dups = dups_finder.dup_contact_sets
      expect(dups.size).to eq(0)
    end

    it 'finds duplicates by people with matching nickname' do
      nickname # create the nickname in the let expression above
      john_doe1.update_column(:first_name, 'Johnny')
      expect(dups_finder.dup_contact_sets).to_not be_empty
    end

    it 'finds duplicates by people with matching email' do
      john_doe1.update_column(:first_name, 'Not-John')
      john_doe1.email = 'same@example.com'
      john_doe1.save
      john_doe2.email = 'Same@Example.com'
      john_doe2.save

      expect(dups_finder.dup_contact_sets).to_not be_empty
    end

    it 'finds duplicates by people with matching phone' do
      john_doe1.update_column(:first_name, 'Not-John')
      john_doe1.phone = '123-456-7890'
      john_doe1.save
      john_doe2.phone = '(123) 456-7890'
      john_doe2.save

      expect(dups_finder.dup_contact_sets).to_not be_empty
    end

    it 'finds duplicates by matching primary address' do
      stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

      john_doe1.update_column(:first_name, 'Not-John')

      john_contact1.addresses_attributes = [{ street: '1 Road', primary_mailing_address: true, master_address_id: 1 }]
      john_contact1.save
      john_contact2.addresses_attributes = [{ street: '1 Rd', primary_mailing_address: true, master_address_id: 1 }]
      john_contact2.save

      expect(dups_finder.dup_contact_sets).to_not be_empty
    end
  end

  # describe '#dup_people_by_same_name ' do
  #   it 'find dups by exactly matching name' do
  #     dups = dups_finder.dup_people_by_same_name
  #     expect(dups.size).to eq(1)
  #     expect(dups.first).to include(john_doe1.id)
  #     expect(dups.first).to include(john_doe2.id)
  #   end
  # end
  #
  # describe '#dup_people_by_nickname_query' do
  #   before do
  #     nickname # create the nickname in the let expression above
  #     john_doe1.update_column(:first_name, 'Johnny')
  #   end
  #
  #   def expect_john_1_2_dup(dup)
  #     expect(dup.person_id).to eq(john_doe1.id)
  #     expect(dup.dup_person_id).to eq(john_doe2.id)
  #     expect(dup.nickname_id).to eq(nickname.id)
  #   end
  #
  #   it 'finds dups by nicknames' do
  #     dups = dups_finder.dup_people_by_nickname_query.to_a
  #     expect(dups.size).to eq(1)
  #     expect(dups.first.shared_contact_id).to be_nil
  #     expect_john_1_2_dup(dups.first)
  #   end
  #
  #   it 'finds dups by nicknames and returns the shared contact_id if it exists' do
  #     john_contact1.people << john_doe2
  #
  #     dups = dups_finder.dup_people_by_nickname_query.to_a
  #     expect(dups.size).to eq(1)
  #     expect(dups.first.shared_contact_id).to eq(john_contact1.id)
  #     expect_john_1_2_dup(dups.first)
  #   end
  # end
  #
  # describe '#dup_people_by_nickname' do
  #   before do
  #     expect(dups_finder).to receive(:dup_people_by_nickname_query)
  #                              .and_return([double(person_id: john_doe1.id, dup_person_id: john_doe2.id,
  #                                                  shared_contact_id: john_contact1.id, nickname_id: nickname.id)])
  #   end
  #
  #   it 'looks up the records for the person, dup_peron and shared contact' do
  #     dups = dups_finder.dup_people_by_nickname
  #     expect(dups.size).to eq(1)
  #     dup = dups.first
  #     expect(dup.person).to eq(john_doe1)
  #     expect(dup.dup_person).to eq(john_doe2)
  #     expect(dup.shared_contact).to eq(john_contact1)
  #     expect(dup.nickname_id).to eq(nickname.id)
  #   end
  #
  #   it 'does not return a person pair if marked as not duplicated to each other' do
  #     john_doe1.update_column(:not_duplicated_with, john_doe2.id.to_s)
  #     expect(dups_finder.dup_people_by_nickname).to eq([])
  #   end
  # end
  #
  # describe '#dup_people_by_same_name' do
  #   it 'finds people in the account list with the same name' do
  #     dups = dups_finder.dup_people_by_same_name
  #     expect(dups.size).to eq(1)
  #     expect(dups.first).to include(john_doe1.id)
  #     expect(dups.first).to include(john_doe2.id)
  #   end
  # end
  #
  # describe '#dup_contacts' do
  #   it 'finds pairs of duplicated contacts by people with same name' do
  #     contact_sets = dups_finder.dup_contact_sets
  #     expect(contact_sets.size).to eq(1)
  #     expect(contact_sets.first).to include(john_contact1)
  #     expect(contact_sets.first).to include(john_contact2)
  #   end
  # end
  #
  # describe '#dup_people' do
  #   it 'finds pairs of duplicated contacts by people with nickname match' do
  #     nickname
  #     john_doe1.update_column(:first_name, 'Johnny')
  #
  #     contact_sets = dups_finder.dup_contact_sets
  #     expect(contact_sets.size).to eq(1)
  #     expect(contact_sets.first).to include(john_contact1)
  #     expect(contact_sets.first).to include(john_contact2)
  #
  #   end
  # end
  #
  # describe '#dup_contacts_and_people' do
  #   before do
  #     nickname
  #     john_doe1.update_column(:first_name, 'Johnny')
  #   end
  #
  #   it 'does not find duplicate people who do not have a contact in common' do
  #     expect(dups_finder.dup_people_sets).to be_empty
  #   end
  #
  #   it 'finds duplicate people who have a contact in common' do
  #     john_contact1.people << john_doe2
  #     john_contact2.destroy
  #
  #     people_sets = dups_finder.dup_people_sets
  #
  #     expect(people_sets.size).to eq(1)
  #     dup = people_sets.first
  #     expect(dup.person).to eq(john_doe1)
  #     expect(dup.dup_person).to eq(john_doe2)
  #     expect(dup.shared_contact).to eq(john_contact1)
  #     expect(dup.nickname_id).to eq(nickname.id)
  #   end
  # end
end
