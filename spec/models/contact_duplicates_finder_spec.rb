require 'spec_helper'

describe ContactDuplicatesFinder do
  let(:account_list) { create(:account_list) }
  let(:dups_finder) { ContactDuplicatesFinder.new(account_list) }

  let(:john_doe1) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_doe2) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_contact1) { create(:contact, name: 'Doe, John 1', account_list: account_list) }
  let(:john_contact2) { create(:contact, name: 'Doe, John 2', account_list: account_list) }

  let(:nickname) { create(:nickname, name: 'john', nickname: 'johnny', suggest_duplicates: true) }

  before do
    john_contact1.people << john_doe1
    john_contact2.people << john_doe2
  end

  describe 'dup_contacts' do
    it 'finds duplicate contacts given pairs of duplicate people' do
      contact_dups = dups_finder.dup_contacts([[john_doe1.id, john_doe2.id]])
      expect(contact_dups.size).to eq(1)
      contact_dup_set = contact_dups.first
      expect(contact_dup_set.size).to eq(2)
      expect(contact_dup_set).to include(john_contact1)
      expect(contact_dup_set).to include(john_contact2)
    end

    it 'does not find duplicates if a contact is marked as not duplicated with the other' do
      john_contact1.update_column(:not_duplicated_with, john_contact2.id)
      expect(dups_finder.dup_contacts([[john_doe1.id, john_doe2.id]])).to eq([])
    end
  end

  describe '#dup_people_by_same_name ' do
    it 'find dups by exactly matching name' do
      dups = dups_finder.dup_people_by_same_name
      expect(dups.size).to eq(1)
      expect(dups.first).to include(john_doe1.id)
      expect(dups.first).to include(john_doe2.id)
    end
  end

  describe '#dup_people_by_nickname_query' do
    before do
      nickname # create the nickname in the let expression above
      john_doe1.update_column(:first_name, 'Johnny')
    end

    def expect_john_1_2_dup(dup)
      expect(dup.person_id).to eq(john_doe1.id)
      expect(dup.dup_person_id).to eq(john_doe2.id)
      expect(dup.nickname_id).to eq(nickname.id)
    end

    it 'finds dups by nicknames' do
      dups = dups_finder.dup_people_by_nickname_query.to_a
      expect(dups.size).to eq(1)
      expect(dups.first.shared_contact_id).to be_nil
      expect_john_1_2_dup(dups.first)
    end

    it 'finds dups by nicknames and returns the shared contact_id if it exists' do
      john_contact1.people << john_doe2

      dups = dups_finder.dup_people_by_nickname_query.to_a
      expect(dups.size).to eq(1)
      expect(dups.first.shared_contact_id).to eq(john_contact1.id)
      expect_john_1_2_dup(dups.first)
    end
  end

  describe '#dup_people_by_nickname' do
    before do
      expect(dups_finder).to receive(:dup_people_by_nickname_query)
                               .and_return([double(person_id: john_doe1.id, dup_person_id: john_doe2.id,
                                                   shared_contact_id: john_contact1.id, nickname_id: nickname.id)])
    end

    it 'looks up the records for the person, dup_peron and shared contact' do
      dups = dups_finder.dup_people_by_nickname
      expect(dups.size).to eq(1)
      dup = dups.first
      expect(dup.person).to eq(john_doe1)
      expect(dup.dup_person).to eq(john_doe2)
      expect(dup.shared_contact).to eq(john_contact1)
      expect(dup.nickname_id).to eq(nickname.id)
    end

    it 'does not return a person pair if marked as not duplicated to each other' do
      john_doe1.update_column(:not_duplicated_with, john_doe2.id.to_s)
      expect(dups_finder.dup_people_by_nickname).to eq([])
    end
  end

  describe '#increment_nicknames_offered' do
    it 'increments the num_times_offered for specified nickname ids' do
      expect(nickname.num_times_offered).to eq(0)
      dups_finder.increment_nicknames_offered([nickname.id])
      nickname.reload
      expect(nickname.num_times_offered).to eq(1)
    end

    it 'does not cause an error if no nickname ids specified' do
      expect { dups_finder.increment_nicknames_offered([]) }.to_not raise_error
    end
  end

  describe '#dup_people_by_same_name' do
    it 'finds people in the account list with the same name' do
      dups = dups_finder.dup_people_by_same_name
      expect(dups.size).to eq(1)
      expect(dups.first).to include(john_doe1.id)
      expect(dups.first).to include(john_doe2.id)
    end
  end

  describe '#dup_contacts_and_people' do
    it 'finds pairs of duplicated contacts by people with same name' do
      contact_sets, people_sets = dups_finder.dup_contacts_and_people
      expect(contact_sets.size).to eq(1)
      expect(contact_sets.first).to include(john_contact1)
      expect(contact_sets.first).to include(john_contact2)

      expect(people_sets).to be_empty
    end

    it 'finds pairs of duplicated contacts by people with nickname match' do
      nickname
      john_doe1.update_column(:first_name, 'Johnny')

      contact_sets, people_sets = dups_finder.dup_contacts_and_people
      expect(contact_sets.size).to eq(1)
      expect(contact_sets.first).to include(john_contact1)
      expect(contact_sets.first).to include(john_contact2)

      expect(people_sets).to be_empty
    end

    it 'finds duplicate people who have a contact in common' do
      nickname
      john_doe1.update_column(:first_name, 'Johnny')
      john_contact1.people << john_doe2
      john_contact2.destroy

      contact_sets, people_sets = dups_finder.dup_contacts_and_people
      expect(contact_sets).to be_empty

      expect(people_sets.size).to eq(1)
      dup = people_sets.first
      expect(dup.person).to eq(john_doe1)
      expect(dup.dup_person).to eq(john_doe2)
      expect(dup.shared_contact).to eq(john_contact1)
      expect(dup.nickname_id).to eq(nickname.id)
    end
  end
end
