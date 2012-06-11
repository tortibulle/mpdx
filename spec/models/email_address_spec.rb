require 'spec_helper'

describe EmailAddress do
  describe 'adding an email address to a person' do
    before(:each) do
      @person = FactoryGirl.create(:person)
      @address =  'test@example.com'
    end
    it "should create an email address if it's new" do
      ->{
        EmailAddress.add_for_person(@person, {email: @address})
        @person.email_addresses.first.email.should == @address
      }.should change(EmailAddress, :count).from(0).to(1)
    end

    it "should not create an email address if it exists" do
      EmailAddress.add_for_person(@person, {email: @address})
      ->{
        EmailAddress.add_for_person(@person, {email: @address})
        @person.email_addresses.first.email.should == @address
      }.should_not change(EmailAddress, :count)
    end

    it "should set only the first email to primary" do
      EmailAddress.add_for_person(@person, {email: @address})
      @person.email_addresses.first.primary?.should == true
      EmailAddress.add_for_person(@person, {email: 'foo' + @address})
      @person.email_addresses.last.primary?.should == false
    end

  end
end
