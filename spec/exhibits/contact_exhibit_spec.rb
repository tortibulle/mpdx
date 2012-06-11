require 'spec_helper'
describe ContactExhibit do

  subject { ContactExhibit.exhibit(contact, context) }
  let(:contact) { build(:contact)}
  let(:context) { double }

  it "returns referrers as a list of links" do
    context.stub!(:link_to).and_return('foo')
    subject.stub!(:referrals_to_me).and_return(['foo','foo'])
    subject.referrer_links.should == 'foo, foo'
  end

  it "should figure out location based on address" do
    subject.stub!(:address).and_return(OpenStruct.new(city: 'Rome', state: 'Empire', country: 'Gross'))
    subject.location.should == 'Rome, Empire, Gross'
  end

  it "should show contact_info" do
    context.stub!(:contact_person_path)
    person = create(:person)
    contact.people << person
    email = build(:email_address, person: person)
    phone_number = build(:phone_number, person: person)
    context.stub!(:link_to).and_return("#{phone_number.number}<br />#{email.email}")
    subject.stub!(:phone_number).and_return(email)
    subject.stub!(:email).and_return(phone_number)
    subject.contact_info.should == "#{phone_number.number}<br />#{email.email}"
  end

  #it "should show return the default avatar filename" do
    #contact.gender = 'female'
    #subject.avatar.should == 'avatar_f.png'
    #contact.gender = 'male'
    #subject.avatar.should == 'avatar.png'
    #contact.gender = nil
    #subject.avatar.should == 'avatar.png'
  #end
end
