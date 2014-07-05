require 'spec_helper'

describe MasterPerson do
  it 'should create a MasterPerson for a new person' do
    ->{
      MasterPerson.find_or_create_for_person(Person.new)
    }.should change(MasterPerson, :count).from(0).to(1)
  end

  it 'should find an existing person based on name and email address' do
    person = create(:person)
    email = create(:email_address, person: person)
    -> {
      person = Person.new(first_name: person.first_name, last_name: person.last_name, suffix: person.suffix)
      person.email = email.email
      person.save!
    }.should_not change(MasterPerson, :count)
  end

  #it "should find an existing person based on name and address" do
    #person = create(:person)
    #address = create(:address, person: person)
    #-> {
      #person = Person.new(first_name: person.first_name, last_name: person.last_name, suffix: person.suffix)
      #person.addresses_attributes = {'0' => address.attributes.with_indifferent_access.slice(:street, :city, :state, :country, :postal_code)}
      #person.save!
    #}.should_not change(MasterPerson, :count)
  #end

  it 'should find an existing person based on name and phone number' do
    person = create(:person)
    phone_number = create(:phone_number, person: person)
    -> {
      person = Person.new(first_name: person.first_name, last_name: person.last_name, suffix: person.suffix)
      person.phone_number = phone_number.attributes.with_indifferent_access.slice(:number, :country_code)
      person.save!
    }.should_not change(MasterPerson, :count)
  end

  it 'should find an existing person based on name and donor account' do
    person = create(:person)
    donor_account = create(:donor_account)
    donor_account.master_people << person.master_person
    donor_account.people << person
    new_person = Person.new(first_name: person.first_name, last_name: person.last_name, suffix: person.suffix)
    MasterPerson.find_for_person(new_person, donor_account: donor_account).should == person.master_person
  end

end
