require 'spec_helper'

describe Person do
  before do
    @person = create(:person)
  end

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
        @person.family_relationships_attributes = {'0' => family_relationship.attributes.with_indifferent_access.except(:id, :person_id, :created_at, :updated_at)}
      }.should change(FamilyRelationship, :count).by(1)
    end
    it 'should destroy a family relationship' do
      family_relationship = create(:family_relationship, person: @person, related_person: create(:person))
      -> {
        @person.family_relationships_attributes = {'0' => family_relationship.attributes.merge(_destroy: '1').with_indifferent_access}
      }.should change(FamilyRelationship, :count).from(1).to(0)
    end
    it 'should update a family relationship' do
      family_relationship = create(:family_relationship, person: @person)
      @person.family_relationships_attributes = {'0' => family_relationship.attributes.merge!(relationship: family_relationship.relationship + 'boo').with_indifferent_access.except(:person_id, :updated_at, :created_at)}
      @person.family_relationships.first.relationship.should == family_relationship.relationship + 'boo'
    end
  end

  describe 'assigning an email address' do
    before(:each) do
      @email =  'test@example.com'
    end
    it 'should create an email' do
      ->{
        @person.email = @email
        @person.email_addresses.first.email.should == @email
      }.should change(EmailAddress, :count).from(0).to(1)
    end
  end

end
