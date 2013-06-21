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
      -> {
        person.family_relationships_attributes = {'0' => family_relationship.attributes.with_indifferent_access.except(:id, :person_id, :created_at, :updated_at)}
      }.should change(FamilyRelationship, :count).by(1)
    end
    it 'should destroy a family relationship' do
      family_relationship = create(:family_relationship, person: person, related_person: create(:person))
      -> {
        person.family_relationships_attributes = {'0' => family_relationship.attributes.merge(_destroy: '1').with_indifferent_access}
      }.should change(FamilyRelationship, :count).from(1).to(0)
    end
    it 'should update a family relationship' do
      family_relationship = create(:family_relationship, person: person)
      person.family_relationships_attributes = {'0' => family_relationship.attributes.merge!(relationship: family_relationship.relationship + 'boo').with_indifferent_access.except(:person_id, :updated_at, :created_at)}
      person.family_relationships.first.relationship.should == family_relationship.relationship + 'boo'
    end
  end

  describe '.save' do
    it "gracefully handles having the same FB account assigned twice" do
      fb_account = create(:facebook_account, person: person)
      person.update_attributes("facebook_accounts_attributes" => {
          "0" => {
            "_destroy" => "false",
            "url" => "http://facebook.com/profile.php?id=500015648"
          },
          "1" => {
            "_destroy" => "false",
            "url" => "http://facebook.com/profile.php?id=500015648"
          },
          "1354203866590" => {
            "_destroy" => "false",
            "id" => fb_account.id,
            "url" => fb_account.url
          }
        })
      person.facebook_accounts.length.should == 2
    end

    it "gracefully handles having an fb account with a blank url" do
      person.update_attributes("facebook_accounts_attributes" => {
          "0" => {
            "_destroy" => "false",
            "url" => ""
          }
        })
      person.facebook_accounts.length.should == 0
    end
  end

  context '#email=' do
    let(:email) { 'test@example.com' }

    it 'creates an email' do
      ->{
        person.email = email
        person.email_addresses.first.email.should == email
      }.should change(EmailAddress, :count).from(0).to(1)
    end
  end

  describe 'merging two people' do
    it "shouldn't fail if the winner has the same facebook account as the loser" do
      @winner = create(:person)
      fb_account = create(:facebook_account, person: @winner)
      @loser = create(:person)
      create(:facebook_account, person: @loser, remote_id: fb_account.remote_id)

      # this shouldn't blow up
      -> {
        @winner.merge(@loser)
      }.should change(Person::FacebookAccount, :count)
    end

    it "should move loser's facebook over" do
      @winner = create(:person)
      @loser = create(:person)
      fb = create(:facebook_account, person: @loser)

      @winner.merge(@loser)
      @winner.facebook_accounts.should == [fb]
    end

    it "should move loser's twitter over" do
      @winner = create(:person)
      @loser = create(:person)
      create(:twitter_account, person: @loser)

      @winner.merge(@loser)
      @winner.twitter_accounts.should_not be_empty
    end
  end

end
