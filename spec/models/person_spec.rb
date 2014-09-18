require 'spec_helper'

describe Person do
  let(:person) { create(:person) }

  describe 'creating a person' do
    it 'should set master_person_id' do
      person = Person.create!(build(:person, master_person: nil).attributes.slice('first_name'))
      person.master_person_id.should_not be_nil
    end
  end

  describe 'saving family relationships' do
    it 'should create a family relationship' do
      family_relationship = build(:family_relationship, person: nil, related_person: create(:person))
      expect {
        person.family_relationships_attributes = { '0' => family_relationship.attributes.with_indifferent_access.except(:id, :person_id, :created_at, :updated_at) }
      }.to change(FamilyRelationship, :count).by(1)
    end
    it 'should destroy a family relationship' do
      family_relationship = create(:family_relationship, person: person, related_person: create(:person))
      expect {
        person.family_relationships_attributes = { '0' => family_relationship.attributes.merge(_destroy: '1').with_indifferent_access }
      }.to change(FamilyRelationship, :count).from(1).to(0)
    end
    it 'should update a family relationship' do
      family_relationship = create(:family_relationship, person: person)
      person.family_relationships_attributes = { '0' => family_relationship.attributes.merge!(relationship: family_relationship.relationship + 'boo').with_indifferent_access.except(:person_id, :updated_at, :created_at) }
      person.family_relationships.first.relationship.should == family_relationship.relationship + 'boo'
    end
  end

  describe '.save' do
    it 'gracefully handles having the same FB account assigned twice' do
      fb_account = create(:facebook_account, person: person)
      person.update_attributes('facebook_accounts_attributes' => {
                                 '0' => {
                                   '_destroy' => 'false',
                                   'url' => 'http://facebook.com/profile.php?id=500015648'
                                 },
                                 '1' => {
                                   '_destroy' => 'false',
                                   'url' => 'http://facebook.com/profile.php?id=500015648'
                                 },
                                 '1354203866590' => {
                                   '_destroy' => 'false',
                                   'id' => fb_account.id,
                                   'url' => fb_account.url
                                 }
                               })
      person.facebook_accounts.length.should == 2
    end

    it 'gracefully handles having an fb account with a blank url' do
      person.update_attributes('facebook_accounts_attributes' => {
                                 '0' => {
                                   '_destroy' => 'false',
                                   'url' => ''
                                 }
                               })
      person.facebook_accounts.length.should == 0
    end

    describe 'saving deceased person' do
      it 'should remove persons name from greeting' do
        contact = create(:contact)
        person.first_name = 'Jack'
        contact.people << person
        contact.people << create(:person, first_name: 'Jill')
        contact.name = 'Smith, Jack and Jill'
        contact.save!
        person.reload
        person.deceased = true
        person.save!
        contact.reload
        expect(contact.name).to_not include('Jack')
      end

      it 'has no stack overflow if deceased person modified' do
        contact = create(:contact)
        person.first_name = 'Jack'
        contact.people << person
        contact.name = 'Smith, Jack'
        contact.save!
        person.reload
        person.deceased = true
        person.save!
        contact.reload
        expect(contact.name).to_not include('Jack')

        person.reload
        person.occupation = 'random change'
        person.save # Used to cause a stack overflow
      end
    end
  end

  context '#email=' do
    let(:email) { 'test@example.com' }

    it 'creates an email' do
      expect {
        person.email = email
        person.email_addresses.first.email.should == email
      }.to change(EmailAddress, :count).from(0).to(1)
    end
  end

  context '#email_address=' do
    it "doesn't barf when someone puts in the same email address twice" do
      person = build(:person)

      email_addresses_attributes = {
        '1378494030167' => {
          '_destroy' => 'false',
          'email' => 'monfortcody@yahoo.com',
          'primary' => '0'
        },
        '1378494031857' => {
          '_destroy' => 'false',
          'email' => 'monfortcody@yahoo.com',
          'primary' => '0'
        }
      }

      person.email_addresses_attributes = email_addresses_attributes

      person.save
    end
  end

  context '#email_addresses_attributes=' do
    let(:person) { create(:person) }
    let(:email) { create(:email_address, person: person) }

    it 'deletes nested email address' do
      email_addresses_attributes = {
        '0' => {
          '_destroy' => '1',
          'email' => 'monfortcody@yahoo.com',
          'primary' => '0',
          'id' => email.id.to_s
        }
      }

      expect {
        person.email_addresses_attributes = email_addresses_attributes

        person.save
      }.to change(person.email_addresses, :count).by(-1)
    end

    it 'updates an existing email address' do
      email_addresses_attributes = {
        '0' => {
          '_destroy' => '0',
          'email' => 'asdf' + email.email,
          'primary' => '1',
          'id' => email.id.to_s
        }
      }

      expect {
        person.email_addresses_attributes = email_addresses_attributes

        person.save
      }.to_not change(person.email_addresses, :count)
    end

    it "doesn't create a duplicate if updating to an address that already exists" do
      email2 = create(:email_address, person: person)

      email_addresses_attributes = {
        '0' => {
          '_destroy' => '0',
          'email' => email.email,
          'primary' => '0',
          'id' => email2.id.to_s
        }
      }

      expect {
        person.email_addresses_attributes = email_addresses_attributes

        person.save
      }.to change(person.email_addresses, :count).by(-1)
    end
  end

  context '#merge' do
    let(:winner) { create(:person) }
    let(:loser) { create(:person) }

    it "shouldn't fail if the winner has the same facebook account as the loser" do
      fb_account = create(:facebook_account, person: winner)
      create(:facebook_account, person: loser, remote_id: fb_account.remote_id)

      # this shouldn't blow up
      expect {
        winner.merge(loser)
      }.to change(Person::FacebookAccount, :count)
    end

    it "should move loser's facebook over" do
      loser = create(:person)
      fb = create(:facebook_account, person: loser)

      winner.merge(loser)
      winner.facebook_accounts.should == [fb]
    end

    it "should move loser's twitter over" do
      loser = create(:person)
      create(:twitter_account, person: loser)

      winner.merge(loser)
      winner.twitter_accounts.should_not be_empty
    end

    it 'moves pictures over' do
      picture = create(:picture, picture_of: loser)
      winner.merge(loser)
      winner.pictures.should include(picture)
    end

    it 'copies over master person sources' do
      loser.master_person.master_person_sources.create(organization_id: 1, remote_id: 2)

      winner.merge(loser)
      expect(winner.master_person.master_person_sources.where(organization_id: 1, remote_id: 2)).to_not be_nil
    end

    it 'creates a Version with a related_object_id', versioning: true do
      p1 = create(:person)
      p2 = create(:person)
      c = create(:contact)
      p1.contacts << c
      p2.contacts << c
      expect {
        p1.merge(p2)
      }.to change(Version, :count).by(1)

      v = Version.last
      expect(v.related_object_id).to eq(c.id)
    end
  end

end
