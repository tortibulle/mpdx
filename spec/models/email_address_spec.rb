require 'spec_helper'

describe EmailAddress do
  describe 'adding an email address to a person' do
    let(:person) { FactoryGirl.create(:person) }
    let(:address) { 'test@example.com' }

    it "should create an email address if it's new" do
      ->{
        EmailAddress.add_for_person(person, {email: address})
        person.email_addresses.first.email.should == address
      }.should change(EmailAddress, :count).from(0).to(1)
    end

    it "doesn't create an email address if it exists" do
      EmailAddress.add_for_person(person, {email: address})
      ->{
        EmailAddress.add_for_person(person, {email: address})
        person.email_addresses.first.email.should == address
      }.should_not change(EmailAddress, :count)
    end

    it "sets only the first email to primary" do
      EmailAddress.add_for_person(person, {email: address})
      person.email_addresses.first.primary?.should == true
      EmailAddress.add_for_person(person, {email: 'foo' + address})
      person.email_addresses.last.primary?.should == false
    end

    it "sets a prior email to not-primary if the new one is primary" do
      email1 = EmailAddress.add_for_person(person, {email: address})
      email1.primary?.should == true

      email2 = EmailAddress.add_for_person(person, {email: 'foo' + address, primary: true})
      email2.primary?.should == true
      email2.send(:ensure_only_one_primary)
      email1.reload.primary?.should == false
    end

  end
end
