require 'spec_helper'

describe DataServer do
  let(:account_list) { create(:account_list) }
  let(:profile) { create(:designation_profile, organization: @org, user: @person.to_user, account_list: account_list) }

  before(:each) do
    @org = create(:organization)
    @person = create(:person)
    @org_account = build(:organization_account, person: @person, organization: @org)
    @data_server = DataServer.new(@org_account)
  end

  it 'should import all' do
    date_from = '01/01/1951'
    @data_server.should_receive(:import_profiles).and_return([profile])
    @data_server.should_receive(:import_donors).with(profile, date_from)
    @data_server.should_receive(:import_donations).with(profile, date_from)
    @data_server.import_all(date_from)
  end

  it 'should return designation numbers for a profile code' do
    designation_numbers = ['031231']
    @data_server.should_receive(:profile_balance).and_return(designation_numbers: designation_numbers)
    @data_server.send(:designation_numbers, profile.code).should == designation_numbers
  end

  it 'should return a list of all profiles with their associated designation numbers' do
    designation_numbers = ['031231']
    profiles = [{ name: 'Profile 1', code: 'Profile 1' }, { name: 'Profile 2', code: '' }]
    @data_server.stub(:designation_numbers).and_return(designation_numbers)
    @data_server.stub(:profiles).and_return(profiles)
    @data_server.profiles_with_designation_numbers.first[:name].should == 'Profile 1'
    @data_server.profiles_with_designation_numbers.first[:designation_numbers].should == designation_numbers
  end

  context '.import_profiles' do
    let(:data_server) { DataServer.new(@org_account) }

    it 'in US format' do
      stub_request(:post, /.*profiles/).to_return(body: "ROLE_CODE,ROLE_DESCRIPTION\n,\"Staff Account (0559826)\"\n")
      stub_request(:post, /.*accounts/).to_return(body: "\"EMPLID\",\"EFFDT\",\"BALANCE\",\"ACCT_NAME\"\n\"0000000\",\"2012-03-23 16:01:39.0\",\"123.45\",\"Test Account\"\n")
      data_server.should_receive(:import_profile_balance)

      expect {
        data_server.import_profiles
      }.to change(DesignationProfile, :count).by(1)
    end
    it 'in DataServer format' do
      stub_request(:post, /.*profiles/).to_return(body: "\xEF\xBB\xBF\"PROFILE_CODE\",\"PROFILE_DESCRIPTION\"\r\n\"1769360689\",\"MPD Coach (All Staff Donations)\"\r\n\"1769360688\",\"My Campus Accounts\"\r\n\"\",\"My Staff Account\"\r\n")
      stub_request(:post, /.*accounts/).to_return(body: "\"EMPLID\",\"EFFDT\",\"BALANCE\",\"ACCT_NAME\"\n\"0000000\",\"2012-03-23 16:01:39.0\",\"123.45\",\"Test Account\"\n")
      expect {
        data_server.import_profiles
      }.to change(DesignationProfile, :count).by(3)
    end
  end

  describe 'import donors' do
    it 'should update the addresses_url on the org if the url changed' do
      stub_request(:post, /.*addresses/).to_return(body: "whatever\nRedirectQueryIni=foo")
      stub_request(:post, 'http://foo:bar@foo/')
      expect {
        @data_server.import_donors(profile)
      }.to change(@org, :addresses_url).to('foo')
    end

    it 'removes a profile that a user no longer has access to' do
      stub_request(:post, /.*addresses/).to_return(body: 'ERROR The user logging in has no profile associated with "1983834942".')
      profile # instantiate record
      expect {
        @data_server.import_donors(profile)
      }.to change(DesignationProfile, :count).by(-1)
    end

    it 'should import a company' do
      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"19238\",\"ACorporation\",\"123 mi casa blvd.\",\"Colima\",\"COL\",\"456788\",\"(52) 45 456-5678\",\"MEX\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"8/15/2003\",\"8/15/2003\",\"\",\"O\",\"ACorporation\",\"\"\r\n")
      @data_server.should_receive(:add_or_update_donor_account)
      @data_server.should_receive(:add_or_update_company)
      @data_server.import_donors(profile)
    end

    it 'should import an individual' do
      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"17083\",\"Rodriguez, Ramon y Celeste (Moreno)\",\"Bahia Acapulco 379\",\"Chihuahua\",\"CHH\",\"24555\",\"(376) 706-670\",\"MEX\",\"Ramon\",\"\",\"Sr.\",\"\",\"Moreno\",\"Celeste\",\"Gonzalez\",\"Sra.\",\"\",\"\",\"\",\"4/4/2003\",\"4/4/2003\",\"\",\"P\",\"Rodriguez\",\"\"\r\n")
      primary_contact = double('person')
      other_person = double('person')
      @data_server.should_receive(:add_or_update_primary_contact).and_return([primary_contact, other_person])
      @data_server.should_receive(:add_or_update_spouse)
      primary_contact.should_receive(:add_spouse)
      other_person.should_receive(:add_spouse)
      @data_server.import_donors(profile)
    end

    it 'should create a new contact in the right account list' do
      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"17083\",\"Rodriguez, Ramon y Celeste (Moreno)\",\"Bahia Acapulco 379\",\"Chihuahua\",\"CHH\",\"24555\",\"(376) 706-670\",\"MEX\",\"Ramon\",\"\",\"Sr.\",\"\",\"Moreno\",\"Celeste\",\"Gonzalez\",\"Sra.\",\"\",\"\",\"\",\"4/4/2003\",\"4/4/2003\",\"\",\"P\",\"Rodriguez\",\"\"\r\n")
      @account_list1 = create(:account_list)
      @account_list2 = create(:account_list)
      profile = create(:designation_profile, user: @org_account.user, account_list: @account_list2)
      @org_account.user.account_lists = [@account_list1, @account_list2]
      expect {
        @data_server.import_donors(profile)
      }.to change(Contact, :count)
      @account_list2.contacts.last.name.should == 'Rodriguez, Ramon y Celeste (Moreno)'
    end

    it 'should create a new person in the right account list and donor account' do
      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"17083\",\"Rodriguez, Ramon y Celeste (Moreno)\",\"Bahia Acapulco 379\",\"Chihuahua\",\"CHH\",\"24555\",\"(376) 706-670\",\"MEX\",\"Ramon\",\"\",\"Sr.\",\"\",\"Moreno\",\"Celeste\",\"Gonzalez\",\"Sra.\",\"\",\"\",\"\",\"4/4/2003\",\"4/4/2003\",\"\",\"P\",\"Rodriguez\",\"\"\r\n")
      @account_list1 = create(:account_list)
      @account_list2 = create(:account_list)
      profile = create(:designation_profile, user: @org_account.user, account_list: @account_list2)
      @org_account.user.account_lists = [@account_list1, @account_list2]
      donor_account = create(:donor_account, organization: @org_account.organization, account_number: '17083')
      expect {
        @data_server.import_donors(profile)
      }.to change(Person, :count)
      new_person = @account_list2.contacts.last.people.last
      new_person.last_name.should == 'Rodriguez'
      new_person.middle_name.should == ''
      new_person.donor_accounts.last.should == donor_account

      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"17083\",\"Rodrigues, Ramon y Celeste (Moreno)\",\"Bahia Acapulco 379\",\"Chihuahua\",\"CHH\",\"24555\",\"(376) 706-670\",\"MEX\",\"Ramon\",\"C\",\"Sr.\",\"\",\"Moreno\",\"Celeste\",\"Gonzalez\",\"Sra.\",\"\",\"\",\"\",\"4/4/2003\",\"4/4/2003\",\"\",\"P\",\"Rodrigues\",\"\"\r\n")
      @data_server.import_donors(profile)
      new_person.reload.last_name.should == 'Rodrigues'
      new_person.middle_name.should == 'C'
    end

    it "should notify Airbrake if PERSON_TYPE is not 'O' or 'P'" do
      stub_request(:post, /.*addresses/).to_return(body: "\"PEOPLE_ID\",\"ACCT_NAME\",\"ADDR1\",\"CITY\",\"STATE\",\"ZIP\",\"PHONE\",\"COUNTRY\",\"FIRST_NAME\",\"MIDDLE_NAME\",\"TITLE\",\"SUFFIX\",\"SP_LAST_NAME\",\"SP_FIRST_NAME\",\"SP_MIDDLE_NAME\",\"SP_TITLE\",\"ADDR2\",\"ADDR3\",\"ADDR4\",\"ADDR_CHANGED\",\"PHONE_CHANGED\",\"CNTRY_DESCR\",\"PERSON_TYPE\",\"LAST_NAME_ORG\",\"SP_SUFFIX\"\r\n\"17083\",\"Rodriguez, Ramon y Celeste (Moreno)\",\"Bahia Acapulco 379\",\"Chihuahua\",\"CHH\",\"24555\",\"(376) 706-670\",\"MEX\",\"Ramon\",\"\",\"Sr.\",\"\",\"Moreno\",\"Celeste\",\"Gonzalez\",\"Sra.\",\"\",\"\",\"\",\"4/4/2003\",\"4/4/2003\",\"\",\"BAD_PERSON_TYPE\",\"Rodriguez\",\"\"\r\n")
      Airbrake.should_receive(:notify)
      @data_server.import_donors(profile)
    end
    it 'should add or update primary contact' do
      @data_server.should_receive(:add_or_update_person)
      @data_server.send(:add_or_update_primary_contact, create(:account_list), '', create(:donor_account))
    end
    it 'should add or update spouse' do
      @data_server.should_receive(:add_or_update_person)
      @data_server.send(:add_or_update_spouse, create(:account_list), '', create(:donor_account))
    end

    describe 'add or update a company' do
      let(:line) { { 'PEOPLE_ID' => '19238', 'ACCT_NAME' => 'ACorporation', 'ADDR1' => '123 mi casa blvd.', 'CITY' => 'Colima', 'STATE' => 'COL', 'ZIP' => '456788', 'PHONE' => '(52) 45 456-5678', 'COUNTRY' => 'MEX', 'FIRST_NAME' => '', 'MIDDLE_NAME' => '', 'TITLE' => '', 'SUFFIX' => '', 'SP_LAST_NAME' => '', 'SP_FIRST_NAME' => '', 'SP_MIDDLE_NAME' => '', 'SP_TITLE' => '', 'ADDR2' => '', 'ADDR3' => '', 'ADDR4' => '', 'ADDR_CHANGED' => '8/15/2003', 'PHONE_CHANGED' => '8/15/2003', 'CNTRY_DESCR' => '', 'PERSON_TYPE' => 'O', 'LAST_NAME_ORG' => 'ACorporation', 'SP_SUFFIX' => '' } }

      before(:each) do
        @account_list = create(:account_list)
        @user = User.find(@person.id)
        @donor_account = create(:donor_account)
      end
      it 'should add a company with an existing master company' do
        create(:company, name: 'ACorporation')
        expect {
          @data_server.send(:add_or_update_company, @account_list, @user, line, @donor_account)
        }.to_not change(MasterCompany, :count)
      end
      it 'should add a company without an existing master company and create a master company' do
        expect {
          @data_server.send(:add_or_update_company, @account_list, @user, line, @donor_account)
        }.to change(MasterCompany, :count).by(1)
      end
      it 'should update an existing company' do
        company = create(:company, name: 'ACorporation')
        @user.account_lists << @account_list
        @account_list.companies << company
        expect {
          new_company = @data_server.send(:add_or_update_company, @account_list, @user, line, @donor_account)
          new_company.should == company
        }.to_not change(Company, :count)
      end
      it 'should associate new company with the donor account' do
        @data_server.send(:add_or_update_company, @account_list, @user, line, @donor_account)
        @donor_account.master_company_id.should_not be_nil
      end
    end

    describe 'add or update contact' do
      let(:line) { { 'PEOPLE_ID' => '17083', 'ACCT_NAME' => 'Rodrigue', 'ADDR1' => 'Ramon y Celeste (Moreno)', 'CITY' => 'Bahia Acapulco 379', 'STATE' => 'Chihuahua', 'ZIP' => 'CHH', 'PHONE' => '24555', 'COUNTRY' => '(376) 706-670', 'FIRST_NAME' => 'MEX', 'MIDDLE_NAME' => 'Ramon', 'TITLE' => '', 'SUFFIX' => 'Sr.', 'SP_LAST_NAME' => '', 'SP_FIRST_NAME' => 'Moreno', 'SP_MIDDLE_NAME' => 'Celeste', 'SP_TITLE' => 'Gonzalez', 'ADDR2' => 'Sra.', 'ADDR3' => '', 'ADDR4' => '', 'ADDR_CHANGED' => '', 'PHONE_CHANGED' => '4/4/2003', 'CNTRY_DESCR' => '4/4/2003', 'PERSON_TYPE' => '', 'LAST_NAME_ORG' => 'P', 'SP_SUFFIX' => 'Rodriguez' } }

      before(:each) do
        @account_list = create(:account_list)
        @user = User.find(@person.id)
        @donor_account = create(:donor_account)
        @donor_account.link_to_contact_for(@account_list)
      end
      it 'should add a contact with an existing master person' do
        mp = create(:master_person)
        @donor_account.organization.master_person_sources.create(master_person_id: mp.id, remote_id: 1)
        expect {
          @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1)
        }.to_not change(MasterPerson, :count)
      end
      it 'should add a contact without an existing master person and create a master person' do
        expect {
          expect {
            @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1)
          }.to change(MasterPerson, :count).by(1)
        }.to change(Person, :count).by(2)
      end

      it 'should add a new contact with no spouse prefix' do
        expect {
          @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1)
        }.to change(MasterPerson, :count).by(1)
      end
      it 'should add a new contact with a spouse prefix' do
        expect {
          @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1, 'SP_')
        }.to change(MasterPerson, :count).by(1)
      end
      it 'should update an existing person' do
        person = create(:person)
        @user.account_lists << @account_list
        @donor_account.master_people << person.master_person
        @donor_account.people << person
        @donor_account.organization.master_person_sources.create(master_person_id: person.master_person_id, remote_id: 1)
        expect {
          new_contact, _other = @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1)
          new_contact.should == person
        }.to_not change(MasterPerson, :count)
      end
      it 'should associate new contacts with the donor account' do
        expect {
          @data_server.send(:add_or_update_person, @account_list, line, @donor_account, 1)
        }.to change(MasterPersonDonorAccount, :count).by(1)
      end
    end
  end

  context '#add_or_update_donor_account' do
    let(:line) { { 'PEOPLE_ID' => '17083', 'ACCT_NAME' => 'Rodrigue', 'ADDR1' => 'Ramon y Celeste (Moreno)', 'CITY' => 'Bahia Acapulco 379', 'STATE' => 'Chihuahua', 'ZIP' => '24555', 'PHONE' => '(376) 706-670', 'COUNTRY' => 'CHH', 'FIRST_NAME' => 'Ramon', 'MIDDLE_NAME' => '', 'TITLE' => '', 'SUFFIX' => 'Sr.', 'SP_LAST_NAME' => '', 'SP_FIRST_NAME' => 'Moreno', 'SP_MIDDLE_NAME' => 'Celeste', 'SP_TITLE' => 'Gonzalez', 'ADDR2' => 'Sra.', 'ADDR3' => '', 'ADDR4' => '', 'ADDR_CHANGED' => '', 'PHONE_CHANGED' => '4/4/2003', 'CNTRY_DESCR' => '4/4/2003', 'PERSON_TYPE' => '', 'LAST_NAME_ORG' => 'P', 'SP_SUFFIX' => 'Rodriguez' } }

    it 'creates a new contact' do
      expect {
        @data_server.send(:add_or_update_donor_account, line, profile)
      }.to change(Contact, :count)
    end

    it "doesn't add duplicate addresses" do
      expect {
        @data_server.send(:add_or_update_donor_account, line, profile)
      }.to change(Address, :count).by(2)
      expect {
        @data_server.send(:add_or_update_donor_account, line, profile)
      }.to change(Address, :count).by(0)
    end
  end

  describe 'check_credentials!' do
    it 'raise an error if credentials are missing' do
      no_user_account = @org_account.dup
      no_user_account.username = nil
      expect {
        DataServer.new(no_user_account).import_donors(profile)
      }.to raise_error(OrgAccountMissingCredentialsError, 'Your username and password are missing for this account.')
      no_pass_account = @org_account.dup
      no_pass_account.password = nil
      expect {
        DataServer.new(no_pass_account).import_donors(profile)
      }.to raise_error(OrgAccountMissingCredentialsError, 'Your username and password are missing for this account.')
    end
    it 'raise an error if credentials are invalid' do
      @org_account.valid_credentials = false
      expect {
        DataServer.new(@org_account).import_donors(profile)
      }.to raise_error(OrgAccountInvalidCredentialsError,
                       _('Your username and password for %{org} are invalid.').localize % { org: @org })
    end
  end

  describe 'validate_username_and_password' do
    it 'should validate using the profiles url if there is one' do
      @data_server.should_receive(:get_params).and_return({})
      @data_server.should_receive(:get_response).with(@org.profiles_url, {})
      @data_server.validate_username_and_password.should == true
    end
    it 'should validate using the account balance url if there is no profiles url' do
      @org.profiles_url = nil
      @data_server.should_receive(:get_params).and_return({})
      @data_server.should_receive(:get_response).with(@org.account_balance_url, {})
      @data_server.validate_username_and_password.should == true
    end
    it 'should return false if the error message says the username/password were wrong' do
      @data_server.should_receive(:get_response).and_raise(DataServerError.new('Either your username or password were incorrect.'))
      @data_server.validate_username_and_password.should == false
    end
    it 'should re-raise other errors' do
      @data_server.should_receive(:get_response).and_raise(DataServerError.new('other error'))
      expect {
        @data_server.validate_username_and_password
      }.to raise_error(DataServerError)
    end

  end

  describe 'get_response' do
    it 'should raise a DataServerError if the first line of the response is ERROR' do
      stub_request(:post, 'http://foo:bar@example.com').to_return(body: "ERROR\nmessage")
      expect {
        @data_server.send(:get_response, 'http://example.com', {})
      }.to raise_error(DataServerError, "ERROR\nmessage")
    end
    it 'should raise a DataServerError if the first line of the response is BAD_PASSWORD' do
      stub_request(:post, 'http://foo:bar@example.com').to_return(body: "BAD_PASSWORD\nmessage")
      expect {
        @data_server.send(:get_response, 'http://example.com', {})
      }.to raise_error(OrgAccountInvalidCredentialsError, 'Your username and password for MyString are invalid.')
    end

  end

  describe 'import account balances' do
    it 'should update a profile balance' do
      stub_request(:post, /.*accounts/).to_return(body: "\"EMPLID\",\"EFFDT\",\"BALANCE\",\"ACCT_NAME\"\n\"0000000\",\"2012-03-23 16:01:39.0\",\"123.45\",\"Test Account\"\n")
      @data_server.should_receive(:check_credentials!)
      expect {
        @data_server.import_profile_balance(profile)
      }.to change(profile, :balance).to(123.45)
    end
    it 'should update a designation account balance' do
      stub_request(:post, /.*accounts/).to_return(body: "\"EMPLID\",\"EFFDT\",\"BALANCE\",\"ACCT_NAME\"\n\"0000000\",\"2012-03-23 16:01:39.0\",\"123.45\",\"Test Account\"\n")
      @designation_account = create(:designation_account, organization: @org, designation_number: '0000000')
      @data_server.import_profile_balance(profile)
      @designation_account.reload.balance.should == 123.45
    end

  end

  describe 'import donations' do
    let(:line) { { 'DONATION_ID' => '1062', 'PEOPLE_ID' => '12271', 'ACCT_NAME' => 'Garci, Reynaldo', 'DESIGNATION' => '10640', 'MOTIVATION' => '', 'PAYMENT_METHOD' => 'EFECTIVO', 'TENDERED_CURRENCY' => 'MXN', 'MEMO' => '', 'DISPLAY_DATE' => '4/23/2003', 'AMOUNT' => '1000.0000', 'TENDERED_AMOUNT' => '1000.0000' } }

    it 'should create a donation' do
      stub_request(:post, /.*donations/).to_return(body: "\xEF\xBB\xBF\"DONATION_ID\",\"PEOPLE_ID\",\"ACCT_NAME\",\"DESIGNATION\",\"MOTIVATION\",\"PAYMENT_METHOD\",\"TENDERED_CURRENCY\",\"MEMO\",\"DISPLAY_DATE\",\"AMOUNT\",\"TENDERED_AMOUNT\"\r\n\"1062\",\"12271\",\"Garcia, Reynaldo\",\"10640\",\"\",\"EFECTIVO\",\"MXN\",\"\",\"4/23/2003\",\"1000.0000\",\"1000.0000\"\r\n")
      @data_server.should_receive(:check_credentials!)
      @data_server.should_receive(:find_or_create_designation_account)
      @data_server.should_receive(:add_or_update_donation)
      @data_server.import_donations(profile, DateTime.new(1951, 1, 1), '2/2/2012')
    end

    it 'should find an existing designation account' do
      account = create(:designation_account, organization: @org, designation_number: line['DESIGNATION'])
      @data_server.send(:find_or_create_designation_account, line['DESIGNATION'], profile).should == account
    end

    it 'should create a new designation account' do
      expect {
        @data_server.send(:find_or_create_designation_account, line['DESIGNATION'], profile)
      }.to change(DesignationAccount, :count)
    end

    describe 'add or update donation' do
      let(:designation_account) { create(:designation_account) }

      it 'should add a new donation' do
        expect {
          @data_server.send(:add_or_update_donation, line, designation_account, profile)
        }.to change(Donation, :count)
      end
      it 'should update an existing donation' do
        @data_server.send(:add_or_update_donation, line, designation_account, profile)
        expect {
          donation = @data_server.send(:add_or_update_donation, line.merge!('AMOUNT' => '5'), designation_account, profile)
          donation.amount == '5'
        }.to_not change(Donation, :count)
      end

    end

  end
end
