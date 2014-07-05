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
      ->{
        FamilyRelationship.add_for_person(@person, @attributes)
        @person.family_relationships.first.relationship.should == @relationship
      }.should change(FamilyRelationship, :count).from(0).to(1)
    end

    it 'should not create a family relationship if it exists' do
      FamilyRelationship.add_for_person(@person, @attributes)
      ->{
        FamilyRelationship.add_for_person(@person, @attributes)
        @person.family_relationships.first.relationship.should == @relationship
      }.should_not change(FamilyRelationship, :count)
    end
  end
end
