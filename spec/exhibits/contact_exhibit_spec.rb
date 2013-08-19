require 'spec_helper'
describe ContactExhibit do

  let(:exhib) { ContactExhibit.new(contact, context) }
  let(:contact) { build(:contact)}
  let(:context) { double }

  it "returns referrers as a list of links" do
    context.stub(:link_to).and_return('foo')
    exhib.stub(:referrals_to_me).and_return(['foo','foo'])
    exhib.referrer_links.should == 'foo, foo'
  end

  it "should figure out location based on address" do
    exhib.stub(:address).and_return(OpenStruct.new(city: 'Rome', state: 'Empire', country: 'Gross'))
    exhib.location.should == 'Rome, Empire, Gross'
  end

  it "should show contact_info" do
    context.stub(:contact_person_path)
    person = create(:person)
    contact.people << person
    email = build(:email_address, person: person)
    phone_number = build(:phone_number, person: person)
    context.stub(:link_to).and_return("#{phone_number.number}<br />#{email.email}")
    exhib.stub(:phone_number).and_return(email)
    exhib.stub(:email).and_return(phone_number)
    exhib.contact_info.should == "#{phone_number.number}<br />#{email.email}"
  end

  it "should not have a newsletter error" do
    contact.send_newsletter = _('Physical')
    contact.addresses << create(:address, addressable: contact, primary_mailing_address: true)
    contact.primary_address.should_not be_nil
    exhib.send_newsletter.should be_present
    exhib.send_newsletter_error.should_not be_present
  end

  it "should have a newsletter error" do
    contact.send_newsletter = _('Physical')
    contact.primary_address.should be_nil
    exhib.send_newsletter.should be_present
    exhib.send_newsletter_error.should be_present
  end

  #it "should show return the default avatar filename" do
    #contact.gender = 'female'
    #exhib.avatar.should == 'avatar_f.png'
    #contact.gender = 'male'
    #exhib.avatar.should == 'avatar.png'
    #contact.gender = nil
    #exhib.avatar.should == 'avatar.png'
  #end
end
