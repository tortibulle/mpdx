require 'spec_helper'

describe ContactDuplicatesFinder do
  let(:account_list) { create(:account_list) }
  let(:dups_finder) { ContactDuplicatesFinder.new(account_list) }

  let(:john_doe1) { create(:person, first_name: 'john', last_name: 'doe') }
  let(:john_doe2) { create(:person, first_name: 'John', last_name: 'Doe') }
  let(:john_contact1) { create(:contact, name: 'Doe, John 1', account_list: account_list) }
  let(:john_contact2) { create(:contact, name: 'Doe, John 2', account_list: account_list) }

  let(:nickname) { create(:nickname, name: 'john', nickname: 'johnny', suggest_duplicates: true) }
  let(:nickname_andy) { create(:nickname, name: 'andrew', nickname: 'andy', suggest_duplicates: true) }

  # Assumes nickname_andy
  MATCHING_FIRST_NAMES = {
    'Grable A' => 'Andy',
    'Grable A' => 'G Andrew',
    'G Andrew' => 'Andy',
    'G Andrew' => 'G Andy',
    'A' => 'Andy',
    'A' => 'Andrew',
    'Andy' => 'Andrew',
    'GA' => 'Andrew',
    'GA' => 'Andy',
    'GA' => 'Grable A',
    'G.A.' => 'Grable A',
    'G.A.' => 'G A',
    'G.A.' => 'Andy',
    'G.A.' => 'Grable',
    'G A.' => 'Andy',
    'G A.' => 'Grable',
    'G A.' => 'Andy',
    'G A.' => 'Grable',
    'A G' => 'Grable',
    'A G' => 'Andrew',
    'Grable Andy' => 'Andrew',
    'Grable Andrew' => 'Andy',
    'Grable Andy' => 'G Andrew',
    'Grable Andrew' => 'G Andy',
    'CC' => 'Charlie',
    'C' => 'Charlie',
    'Hoo-Tee' => 'Hoo Tee',
    'JW' => 'john wilson'
  }

  NON_MATCHING_FIRST_NAMES = {
    'G' => 'Andy',
    'Grable' => 'Andy',
    'Grable B' => 'Andy',
    'G B' => 'Andy',
    'Andrew' => 'Andrea',
    'CCC NEHQ' => 'Charlie'
  }

  before do
    john_contact1.people << john_doe1
    john_contact2.people << john_doe2
  end

  describe '#dup_people_sets ' do
    it 'does not find duplicates with no shared contact' do
      expect(dups_finder.dup_people_sets).to be_empty
    end

    describe 'finding duplicates with a shared contact' do
      before do
        john_contact1.people << john_doe2
      end

      def expect_johns_people_set
        dups = dups_finder.dup_people_sets
        expect(dups.size).to eq(1)
        dup = dups.first
        expect([dup.person, dup.dup_person]).to include(john_doe1)
        expect([dup.person, dup.dup_person]).to include(john_doe2)
        expect(dup.shared_contact).to eq(john_contact1)
      end

      it 'finds duplicates by same name' do
        expect_johns_people_set
      end

      it 'does not find duplicates if no matching info' do
        john_doe1.update_column(:first_name, 'Notjohn')
        expect(dups_finder.dup_people_sets).to be_empty
      end

      it 'does not find duplicates if people marked as not duplicated with each other' do
        john_doe1.update_column(:not_duplicated_with, john_doe2.id.to_s)
        expect(dups_finder.dup_people_sets).to be_empty
      end

      it 'finds duplicates by nickname' do
        nickname
        john_doe1.update_column(:first_name, 'johnny')

        dups = dups_finder.dup_people_sets
        expect(dups.size).to eq(1)
        dup = dups.first

        # Expect the person with the nickname to be dup.person, while the full name to be dup_person
        # That will cause the default merged person to have the nickname.
        expect(dup.person).to eq(john_doe1)
        expect(dup.dup_person).to eq(john_doe2)

        expect(dup.shared_contact).to eq(john_contact1)
      end

      it 'finds duplicates by nickname in correct order and without extra rows if other matching info there' do
        john_doe1.email = 'same@example.com'
        john_doe1.save
        john_doe2.email = 'Same@Example.com'
        john_doe2.save

        # Make john_doe2 the one with the nickname. Even though he has a bigger id, he should come first
        # in the pairing because he has the nickname. The duplicate pair from the email which would prefer a lower
        # id to be unique i.e. with john_doe1 as the person and john_doe2 as the dup person should be eliminated.
        expect(john_doe2.id > john_doe1.id).to be_true
        john_doe2.update_column(:first_name, 'johnny')
        nickname

        dups = dups_finder.dup_people_sets
        expect(dups.size).to eq(1)
        dup = dups.first

        # Expect the person with the nickname to be dup.person, while the full name to be dup_person
        # That will cause the default merged person to have the nickname.
        expect(dup.person).to eq(john_doe2)
        expect(dup.dup_person).to eq(john_doe1)

        expect(dup.shared_contact).to eq(john_contact1)
      end

      it 'finds duplicates by email' do
        john_doe1.update_column(:first_name, 'Notjohn')
        john_doe1.email = 'same@example.com'
        john_doe1.save
        john_doe2.email = 'Same@Example.com'
        john_doe2.save

        expect_johns_people_set
      end

      it 'finds duplicates by phone' do
        john_doe1.update_column(:first_name, 'Notjohn')
        john_doe1.phone = '123-456-7890'
        john_doe1.save
        john_doe2.phone = '(123) 456-7890'
        john_doe2.save

        expect_johns_people_set
      end

      it 'does not find duplicates by phone or email if the people have different genders' do
        john_doe1.update_column(:first_name, 'Notjohn')
        john_doe1.update_column(:gender, 'female')
        john_doe2.update_column(:gender, 'male')

        john_doe1.phone = '123-456-7890'
        john_doe1.email = 'same@example.com'
        john_doe1.save
        john_doe2.phone = '(123) 456-7890'
        john_doe2.email = 'Same@Example.com'
        john_doe2.save

        expect(dups_finder.dup_people_sets).to be_empty
      end

      def expect_matching_people(first_names)
        john_doe1.update_column(:first_name, first_names[0])
        john_doe2.update_column(:first_name, first_names[1])
        expect_johns_people_set
      end

      def expect_non_matching_people(first_names)
        john_doe1.update_column(:first_name, first_names[0])
        john_doe2.update_column(:first_name, first_names[1])
        expect(dups_finder.dup_people_sets).to be_empty
      end

      it 'finds people by matching initials and middle names in the first name field' do
        nickname_andy
        MATCHING_FIRST_NAMES.each(&method(:expect_matching_people))
        NON_MATCHING_FIRST_NAMES.each(&method(:expect_non_matching_people))
      end
    end
  end

  describe '#dup_contact_sets' do
    def expect_johns_contact_set
      dups = dups_finder.dup_contact_sets
      expect(dups.size).to eq(1)
      dup = dups.first
      expect(dup.size).to eq(2)
      expect(dup).to include(john_contact1)
      expect(dup).to include(john_contact2)
    end

    it 'finds duplicate contacts given for people with the same name' do
      expect_johns_contact_set
    end

    it 'does not find duplicates if contacts have no matching info' do
      john_doe1.update_column(:first_name, 'Notjohn')
      expect(dups_finder.dup_contact_sets).to be_empty
    end

    it 'does not find duplicates if a contact is marked as not duplicated with the other' do
      john_contact1.update_column(:not_duplicated_with, john_contact2.id)

      dups = dups_finder.dup_contact_sets
      expect(dups.size).to eq(0)
    end

    it 'finds duplicates by people with matching nickname' do
      nickname # create the nickname in the let expression above
      john_doe1.update_column(:first_name, 'Johnny')
      expect_johns_contact_set
    end

    it 'finds duplicates by people with matching email' do
      john_doe1.update_column(:first_name, 'Notjohn')
      john_doe1.email = 'same@example.com'
      john_doe1.save
      john_doe2.email = 'Same@Example.com'
      john_doe2.save

      expect_johns_contact_set
    end

    it 'finds duplicates by people with matching phone' do
      john_doe1.update_column(:first_name, 'Notjohn')
      john_doe1.phone = '123-456-7890'
      john_doe1.save
      john_doe2.phone = '(123) 456-7890'
      john_doe2.save

      expect_johns_contact_set
    end

    it 'finds duplicates by matching primary address' do
      stub_request(:get, %r{http://api\.smartystreets\.com/street-address/.*}).to_return(body: '[]')

      john_doe1.update_column(:first_name, 'Notjohn')

      john_contact1.addresses_attributes = [{ street: '1 Road', primary_mailing_address: true, master_address_id: 1 }]
      john_contact1.save
      john_contact2.addresses_attributes = [{ street: '1 Rd', primary_mailing_address: true, master_address_id: 1 }]
      john_contact2.save

      expect_johns_contact_set
    end

    it 'does not find the same contact as a duplicate if the persons name would match itself' do
      john_doe1.update_column(:first_name, 'John B')
      john_doe2.update_column(:first_name, 'Brian')
      john_contact1.people << john_doe2
      john_contact2.destroy

      expect(dups_finder.dup_contact_sets).to be_empty
    end

    def expect_matching_contacts(first_names)
      john_doe1.update_column(:first_name, first_names[0])
      john_doe2.update_column(:first_name, first_names[1])
      expect_johns_contact_set
    end

    def expect_non_matching_contacts(first_names)
      john_doe1.update_column(:first_name, first_names[0])
      john_doe2.update_column(:first_name, first_names[1])
      expect(dups_finder.dup_contact_sets).to be_empty
    end

    it 'finds people by matching initials and middle names in the first name field' do
      nickname_andy
      MATCHING_FIRST_NAMES.each(&method(:expect_matching_contacts))
      NON_MATCHING_FIRST_NAMES.each(&method(:expect_non_matching_contacts))
    end
  end
end
