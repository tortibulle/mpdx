require 'spec_helper'

describe Siebel do
  let(:org) { create(:organization) }
  let(:person) { create(:person) }
  let(:org_account) { build(:organization_account, person: person, organization: org) }
  let(:account_list) { create(:account_list) }
  let(:designation_profile) { create(:designation_profile, user: person.to_user, organization: org, account_list: account_list) }
  let!(:siebel) { Siebel.new(org_account) }
  let(:da1) { build(:designation_account, staff_account_id: 1, organization: org) }
  let(:da2) { build(:designation_account, staff_account_id: 2, organization: org) }
  let(:donor_account) { create(:donor_account, organization: org) }
  let(:contact) { create(:contact) }
  let(:siebel_donor) { SiebelDonations::Donor.new(Oj.load('{ "id": "602506447", "accountName": "Hillside Evangelical Free Church", "contacts": [ { "id": "1-2XH-663", "primary": true, "firstName": "Friend", "lastName": "of the Ministry", "sex": "Unspecified", "phoneNumbers": [ { "id": "1-CI7-4832", "type": "Work", "primary": true, "phone": "408/269-4782" } ] } ], "addresses": [ { "id": "1-HS7-779", "type": "Mailing", "primary": true, "seasonal": false, "address1": "545 Hillsdale Ave", "city": "San Jose", "state": "CA", "zip": "95136-1202" } ], "type": "Business" }')) }

  before do
    account_list.users << person.to_user
  end

  context '#import_profiles' do
    let(:relay) { create(:relay_account, person: person) }

    it 'imports profiles for a relay guid' do
      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/profiles?response_timeout=60000&ssoGuid=#{relay.remote_id}").
        to_return(:status => 200, :body => '[ { "name": "Staff Account (0559826)", "designations": [ { "number": "0559826", "description": "Joshua and Amanda Starcher (0559826)", "staffAccountId": "000559826" } ] }]')

      siebel.should_receive(:find_or_create_designation_account)

      expect {
        siebel.import_profiles
      }.to change {DesignationProfile.count}.by(1)
    end

    #it 'removes profiles that a user no longer has access to' do
      #stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/profiles?response_timeout=60000&ssoGuid=#{relay.remote_id}").
        #to_return(:status => 200, :body => '[ ]')

      #designation_profile = create(:designation_profile, user: person.to_user, organization: org)

      #expect {
        #siebel.import_profiles
      #}.to change {DesignationProfile.count}.by(-1)

    #end
  end

  context '#import_profile_balance' do

    it "sets the profile balance to the sum of designation account balances in this profile" do
      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/staffAccount/balances?employee_ids=1&response_timeout=60000").
        to_return(:status => 200, :body => '{ "1": { "primary": 1 }}')
      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/staffAccount/balances?employee_ids=2&response_timeout=60000").
        to_return(:status => 200, :body => '{ "2": { "primary": 2 }}')

      designation_profile.designation_accounts << da1
      designation_profile.designation_accounts << da2

      siebel.import_profile_balance(designation_profile)

      designation_profile.balance.should == 3
    end

    it "updates the balance of a designation account on that profile" do
      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/staffAccount/balances?employee_ids=1&response_timeout=60000").
        to_return(:status => 200, :body => '{ "1": { "primary": 1 }}')

      designation_profile.designation_accounts << da1

      siebel.import_profile_balance(designation_profile)

      da1.balance.should == 1

    end
  end

  context '#import_donations' do
    it "imports a new donation from the donor system" do
      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/donations?designations=#{da1.designation_number}&end_date=#{Date.today.strftime('%Y-%m-%d')}&response_timeout=60000&start_date=2004-01-01").
        to_return(:status => 200, :body => '[ { "id": "1-IGQAM", "amount": "100.00", "designation": "' + da1.designation_number + '", "donorId": "439362786", "donationDate": "2012-12-18", "postedDate": "2012-12-21", "paymentMethod": "Check", "channel": "Mail", "campaignCode": "000000" } ]')

      designation_profile.designation_accounts << da1

      siebel.should_receive(:add_or_update_donation)
      siebel.import_donations(designation_profile)
    end
  end

  context '#find_or_create_designation_account' do
    it "creates a designation account when it can't find one" do
      expect {
        siebel.send(:find_or_create_designation_account, '1', designation_profile,
                                                         {name: 'foo'})

      }.to change {DesignationAccount.count}.by(1)
    end

    it "updates an existing designation account" do
      da1.save

      expect {
        siebel.send(:find_or_create_designation_account, da1.designation_number, designation_profile,
                                                         {name: 'foo'})

      }.not_to change {DesignationAccount.count}

      da1.reload.name.should == 'foo'
    end

  end

  context '#add_or_update_donation' do
    let(:siebel_donation) { SiebelDonations::Donation.new(Oj.load('{ "id": "1-IGQAM", "amount": "100.00", "designation": "' + da1.designation_number + '", "donorId": "' + donor_account.account_number + '", "donationDate": "2012-12-18", "postedDate": "2012-12-21", "paymentMethod": "Check", "channel": "Mail", "campaignCode": "000000" }')) }

    before do
      da1.save
    end

    it 'creates a new donation' do
      expect {
        siebel.send(:add_or_update_donation, siebel_donation, da1, designation_profile)
      }.to change { Donation.count }.by(1)
    end

    it "updates an existing donation" do
      donation = create(:donation, remote_id: "1-IGQAM", amount: 5, designation_account: da1)

      expect {
        siebel.send(:add_or_update_donation, siebel_donation, da1, designation_profile)
      }.not_to change { Donation.count }.by(1)
    end

    it "doesn't save the donation if the donor can't be found" do
      donor_account.destroy

      expect {
        siebel.send(:add_or_update_donation, siebel_donation, da1, designation_profile)
      }.not_to change { Donation.count }.by(1)
    end
  end

  context '#import_donors' do
    it "imports a new donor from the donor system" do
      designation_profile.designation_accounts << da1

      stub_request(:get, "https://wsapi.ccci.org/wsapi/rest/donors?having_given_to_designations=#{da1.designation_number}&response_timeout=60000").
        to_return(:status => 200, :body => '[{"id":"602506447","accountName":"HillsideEvangelicalFreeChurch","type":"Business"}]')

      siebel.should_receive(:add_or_update_donor_account)
      siebel.should_receive(:add_or_update_company)
      siebel.import_donors(designation_profile)
    end
  end

  context '#add_or_update_donor_account' do
    it "adds a new donor account" do
      siebel.should_receive(:add_or_update_person)
      siebel.should_receive(:add_or_update_address).twice

      expect {
        siebel.send(:add_or_update_donor_account, account_list, siebel_donor, designation_profile)
      }.to change { DonorAccount.count }.by(1)
    end

    it "updates an existing donor account" do
      donor_account = create(:donor_account, organization: org, account_number: siebel_donor.id)

      siebel.should_receive(:add_or_update_person)
      siebel.should_receive(:add_or_update_address).twice

      expect {
        siebel.send(:add_or_update_donor_account, account_list, siebel_donor, designation_profile)
      }.not_to change { DonorAccount.count }

      donor_account.reload.name.should == siebel_donor.account_name
    end
  end

  context '#add_or_update_person' do
    let(:siebel_person) { SiebelDonations::Contact.new(Oj.load('{"id":"1-3GJ-2744","primary":true,"firstName":"Jean","preferredName":"Jean","lastName":"Spansel","title":"Mrs","sex":"F"}')) }

    it "adds a new person" do
      siebel_person_with_rels = SiebelDonations::Contact.new(Oj.load('{"id":"1-3GJ-2744","primary":true,"firstName":"Jean","preferredName":"Jean","lastName":"Spansel","title":"Mrs","sex":"F","emailAddresses":[{"id":"1-CEX-8425","type":"Home","primary":true,"email":"markmarthaspansel@gmail.com"}],"phoneNumbers":[{"id":"1-BTE-2524","type":"Work","primary":true,"phone":"510/656-7873"}]}'))

      siebel.should_receive(:add_or_update_email_address).twice
      siebel.should_receive(:add_or_update_phone_number).twice

      expect {
        siebel.send(:add_or_update_person, siebel_person_with_rels, donor_account, contact)
      }.to change { Person.count }.by(2)
    end

    it "updates an existing person" do
      mp = MasterPerson.create
      mps = MasterPersonSource.create({master_person_id: mp.id, organization_id: org.id, remote_id: siebel_person.id}, without_protection: true)
      p = create(:person, master_person_id: mp.id)
      donor_account.people << p
      cp = contact.add_person(p)

      expect {
        siebel.send(:add_or_update_person, siebel_person, donor_account, contact)
      }.not_to change { Person.count }

      p.reload.legal_first_name.should == siebel_person.first_name

    end

    it "find and updates an old-style remote_id" do
      # Set up a person with the old style remote id
      mp = MasterPerson.create
      mps = MasterPersonSource.create({master_person_id: mp.id, organization_id: org.id, remote_id: donor_account.account_number + '-1'}, without_protection: true)

      expect {
        siebel.send(:add_or_update_person, siebel_person, donor_account, contact)
      }.not_to change { MasterPersonSource.count }

      mps.reload.remote_id.should == siebel_person.id
    end

    it "maps sex=M to gender=male" do
      siebel_person = SiebelDonations::Contact.new(Oj.load('{"id":"1-3GJ-2744","primary":true,"firstName":"Jean","preferredName":"Jean","lastName":"Spansel","title":"Mrs","sex":"M"}'))

      p = siebel.send(:add_or_update_person, siebel_person, donor_account, contact).first
      p.gender.should == 'male'
    end

    it "maps sex=Undetermined to gender=nil" do
      siebel_person = SiebelDonations::Contact.new(Oj.load('{"id":"1-3GJ-2744","primary":true,"firstName":"Jean","preferredName":"Jean","lastName":"Spansel","title":"Mrs","sex":"Undetermined"}'))

      p = siebel.send(:add_or_update_person, siebel_person, donor_account, contact).first
      p.gender.should be_nil
    end

  end

  context '#add_or_update_address' do
    let(:siebel_address) { SiebelDonations::Address.new(Oj.load('{"id":"1-IQ5-1006","type":"Mailing","primary":true,"seasonal":false,"address1":"1697 } Marabu Way","city":"Fremont","state":"CA","zip":"94539-3683"}')) }

    it "adds a new address" do
      expect {
        siebel.send(:add_or_update_address, siebel_address, contact)
      }.to change{Address.count}.by(1)
    end

    it "updates an existing address" do
      address = create(:address, addressable: contact, remote_id: siebel_address.id)
      expect {
        siebel.send(:add_or_update_address, siebel_address, contact)
      }.not_to change { Address.count }

      address.reload.postal_code.should == siebel_address.zip
    end

    it 'raises an error if the address is invalid' do
      siebel_address = SiebelDonations::Address.new(Oj.load('{"id":"1-IQ5-1006","type":"BAD_TYPE"}'))
      expect {
        siebel.send(:add_or_update_address, siebel_address, contact)
      }.to raise_exception
    end
  end

  context '#add_or_update_phone_number' do
    let(:siebel_phone_number) { SiebelDonations::PhoneNumber.new(Oj.load('{"id":"1-CI7-4832","type":"Work","primary":true,"phone":"408/269-4782"}')) }

    it "adds a new phone number" do
      expect {
        siebel.send(:add_or_update_phone_number, siebel_phone_number, person)
      }.to change { PhoneNumber.count }.by(1)
    end

    it "updates an existing phone number" do
      pn = create(:phone_number, person: person, remote_id: siebel_phone_number.id)

      expect {
        siebel.send(:add_or_update_phone_number, siebel_phone_number, person)
      }.not_to change { PhoneNumber.count }

      pn.reload.number.should == PhoneNumber.strip_number(siebel_phone_number.phone)
    end
  end

  context '#add_or_update_email_address' do
    let(:siebel_email) { SiebelDonations::EmailAddress.new(Oj.load('{"id":"1-CEX-8425","type":"Home","primary":true,"email":"markmarthaspansel@gmail.com"}')) }

    it "adds a new email address" do
      expect {
        siebel.send(:add_or_update_email_address, siebel_email, person)
      }.to change { EmailAddress.count }.by(1)
    end

    it "updates an existing email address" do
      email = create(:email_address, person: person, remote_id: siebel_email.id)

      expect {
        siebel.send(:add_or_update_email_address, siebel_email, person)
      }.not_to change { EmailAddress.count }

      email.reload.email.should == siebel_email.email
    end
  end

  context '#add_or_update_company' do
    it "adds a new company" do
      expect {
        siebel.send(:add_or_update_company, account_list, siebel_donor, donor_account)
      }.to change { Company.count }.by(1)
    end

    it "updates an existing company" do
      mc = create(:master_company, name: siebel_donor.account_name)
      company = create(:company, master_company: mc)
      account_list.companies << company

      expect {
        siebel.send(:add_or_update_company, account_list, siebel_donor, donor_account)
      }.not_to change { Company.count }

      company.reload.name.should == siebel_donor.account_name
    end
  end

  context '#profiles_with_designation_numbers' do
    it 'returns a hash of attributes' do
      siebel.should_receive(:profiles).and_return([SiebelDonations::Profile.new({"id"=>"","name"=>"Profile 1","designations"=>[{"number"=>"1234"}]})])
      siebel.profiles_with_designation_numbers.should == [{name: 'Profile 1', code: '', designation_numbers: ['1234']}]
    end
  end
end

