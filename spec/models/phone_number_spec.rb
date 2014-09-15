require 'spec_helper'

describe PhoneNumber do
  describe 'adding a phone number to a person' do
    before(:each) do
      @person = FactoryGirl.create(:person)
      @attributes = { 'number' => '123-345-2313' }
    end
    it "creates a phone number if it's new" do
      expect {
        PhoneNumber.add_for_person(@person, @attributes)
        phone_number = @person.reload.phone_numbers.first
        phone_number.number.should == '+11233452313'
      }.to change(PhoneNumber, :count).from(0).to(1)
    end

    it "doesn't create a phone number if it exists" do
      PhoneNumber.add_for_person(@person, @attributes)
      expect {
        PhoneNumber.add_for_person(@person, @attributes)
        @person.phone_numbers.first.number.should == '+11233452313'
      }.to_not change(PhoneNumber, :count)
    end

    it 'sets only the first phone number to primary' do
      PhoneNumber.add_for_person(@person, @attributes)
      @person.phone_numbers.first.primary?.should == true
      PhoneNumber.add_for_person(@person, @attributes.merge('number' => '313-313-3142'))
      @person.phone_numbers.last.primary?.should == false
    end

    it 'sets a prior phone number to not-primary if the new one is primary' do
      phone1 = PhoneNumber.add_for_person(@person, @attributes)
      phone1.primary?.should == true

      phone2 = PhoneNumber.add_for_person(@person,  number: '313-313-3142', primary: true)
      phone2.primary?.should == true
      phone2.send(:ensure_only_one_primary)
      phone1.reload.primary?.should == false
    end

  end

  describe 'clean_up_number' do
    it 'should parse out the country code' do
      pn = PhoneNumber.new(number: '+44 12345532')
      pn.clean_up_number
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
