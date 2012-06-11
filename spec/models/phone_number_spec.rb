require 'spec_helper'

describe PhoneNumber do
  describe 'adding a phone number to a person' do
    before(:each) do
      @person = FactoryGirl.create(:person)
      @attributes = {'number' => '123-345-2313'}
    end
    it "should create a phone number if it's new" do
      ->{
        PhoneNumber.add_for_person(@person, @attributes)
        @person.phone_numbers.first.number.should == PhoneNumber.strip_number(@attributes['number'])
      }.should change(PhoneNumber, :count).from(0).to(1)
    end

    it "should not create a phone number if it exists" do
      PhoneNumber.add_for_person(@person, @attributes)
      ->{
        PhoneNumber.add_for_person(@person, @attributes)
        @person.phone_numbers.first.number.should == PhoneNumber.strip_number(@attributes['number'])
      }.should_not change(PhoneNumber, :count)
    end

    it "should set only the first phone number to primary" do
      PhoneNumber.add_for_person(@person, @attributes)
      @person.phone_numbers.first.primary?.should == true
      PhoneNumber.add_for_person(@person, @attributes.merge('number' => '313-313-3142'))
      @person.phone_numbers.last.primary?.should == false
    end

  end

  describe 'strip_number!' do
    it "should parse out the country code" do
      pn = PhoneNumber.new(number: '+44 12345532')
      pn.send(:strip_number!)
      pn.country_code.should == '44'
    end
  end

  #it 'should format a US number based on country code' do
    #p = PhoneNumber.new(number: '1567890', country_code: '1')
    #p.to_s.should == '156-7890'
  #end
  #it 'should format a US number based on length' do
    #p = PhoneNumber.new(number: '1234567890', country_code: nil)
    #p.to_s.should == '(123) 456-7890'
  #end
  #it 'should leave all other countries alone' do
    #p = PhoneNumber.new(number: '1234567890', country_code: '999999999')
    #p.to_s.should == '1234567890'
  #end

end
