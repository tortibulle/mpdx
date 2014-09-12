require 'spec_helper'

describe FamilyRelationship do
  describe 'adding a family relationship to a person' do
    before(:each) do
      @person = FactoryGirl.create(:person)
      @wife = FactoryGirl.create(:person)
      @relationship =  'wife'
      @attributes = { related_person_id: @wife.id, relationship: @relationship }
    end
    it "should create a family relationship if it's new" do
      expect {
        FamilyRelationship.add_for_person(@person, @attributes)
        @person.family_relationships.first.relationship.should == @relationship
      }.to change(FamilyRelationship, :count).from(0).to(1)
    end

    it 'should not create a family relationship if it exists' do
      FamilyRelationship.add_for_person(@person, @attributes)
      expect {
        FamilyRelationship.add_for_person(@person, @attributes)
        @person.family_relationships.first.relationship.should == @relationship
      }.to_not change(FamilyRelationship, :count)
    end
  end
end
