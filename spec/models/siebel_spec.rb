require 'spec_helper'

describe Siebel do
  before(:each) do
    @org = FactoryGirl.create(:organization)
    @person = FactoryGirl.create(:person)
    @org_account = FactoryGirl.build(:organization_account, person: @person, organization: @org)
    @designation_profile = create(:designation_profile, user: @person.to_user, organization: @org)
    @siebel = Siebel.new(@org_account)
  end

  #it "should initialize" do
    #@siebel.should_not be nil
  #end


  #describe "import all function" do
    #it "should run processes" do
      #@siebel.should_receive(:import_profiles)
      #@siebel.should_receive(:import_profile_balance).with(@designation_profile)
      #@siebel.should_receive(:import_donors)
      #@siebel.should_receive(:import_donations)
      #@siebel.import_all
    #end
  #end

  #describe "response function" do

    #it "should send request profile to Siebel API" do
      #stub_request(:post, "http://www.domain.com/profiles/1/list").
        #with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
        #to_return(:status => 200, :body => "profile_list", :headers => {})
      #@response = @siebel.send(:get_response, @org_account.remote_id, 'profiles')
      #@response.should == 'profile_list'
    #end

    #it "should send request donors to Siebel API" do
      #stub_request(:post, "http://www.domain.com/desigdata/1/donors").
        #with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
        #to_return(:status => 200, :body => "donor_list", :headers => {})
      #@response = @siebel.send(:get_response, @org_account.remote_id, 'donors')
      #@response.should == 'donor_list'
    #end

    #it "should send request donations to Siebel API" do
      #stub_request(:post, "http://www.domain.com/desigdata/1/donations").
        #with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
        #to_return(:status => 200, :body => "donation_list", :headers => {})
      #@response = @siebel.send(:get_response, @org_account.remote_id, 'donations')
      #@response.should == 'donation_list'
    #end

    #it "should send request balances to Siebel API" do
      #stub_request(:post, "http://www.domain.com/accounts/balances").
        #with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
        #to_return(:status => 200, :body => "balance_list", :headers => {})
      #@response = @siebel.send(:get_response, @designation_profile.remote_id, 'balances')
      #@response.should == 'balance_list'
    #end
  #end

  #describe "import profile balance function" do
    #it "should raise error if parameter profile is nil" do
      #-> {
        #@siebel.import_profile_balance
      #}.should raise_error(ArgumentError)
    #end

    #it "should import balances" do
      #@designation_account = create(:designation_account)
      #@org.designation_accounts << @designation_account
      #params = "?accounts=#{@org.designation_accounts.select {|a| a.present?}.join(',')}"
      #@response = @siebel.should_receive(:get_response).with(@designation_profile.remote_id, "balances", params).and_return { JSON.parse('[{"employee_id":"000552345","effective_date":"2012-03-0717:42:49.0","account_name":"Starcher,JoshuaL&Amanda","account":"0552345","balance":1224.31},{"account":"0552346","balance":4124.31}]') }
      #@siebel.import_profile_balance(@designation_profile)
      #@first_updated_designation_account = @designation_profile.designation_accounts.where(:designation_number => @response[0][0]['account']).first
      #@first_updated_designation_account.balance_updated_at.should == "2012-03-07 17:42:49"
      #@first_updated_designation_account.name.should == "Starcher,JoshuaL&Amanda"
      #@first_updated_designation_account.balance.to_f.should == 1224.31
      #@second_updated_designation_account = @designation_profile.designation_accounts.where(:designation_number => @response[0][1]['account']).first
      #@second_updated_designation_account.name.should be nil
      #@second_updated_designation_account.balance.to_f.should == 4124.31
    #end
  #end

  #describe "import profiles function" do
    #it "should import profile" do
      #@siebel.should_receive(:get_response).with(@org_account.remote_id, "profiles").and_return { JSON.parse('[{"id":"STAFF","name":"StaffAccount(0559826)","designation_numbers":["0559826"],"account_ids":["0000559826"]}]') }
      #@designation_profile = double(:designation_profile, organization: @org, user: @person)
      #@designation_account = double(:designation_account, organization: @org)
      #@designation_profile_account = double(:designation_profile_account,
                                            #designation_profile: @designation_profile,
                                            #designation_account: @designation_account)
      #@siebel.should_receive(:find_or_create_designation_profile).and_return(@designation_profile)
      #@siebel.should_receive(:find_or_create_designation_account).and_return(@designation_account)
      #@siebel.should_receive(:link_profile_to_account).and_return(@designation_profile_account)
      #@siebel.import_profiles
    #end
    #it "should create designation profile" do
      #@designation_profile = @siebel.send(:find_or_create_designation_profile, @org_account, JSON.parse('{"id":"STAFF","name":"StaffAccount(0559826)","designation_numbers":["0559826"],"account_ids":["0000559826"]}'))
      #@designation_profile.remote_id.should == 'STAFF'
      #@designation_profile.name.should == 'StaffAccount(0559826)'
    #end
    #it "should create designation account" do
      #@designation_account = @siebel.send(:find_or_create_designation_account, @designation_profile, '0559826')
      #@designation_account.designation_number.should == '0559826'
      #@designation_account.organization.id.should == @org.id
    #end
    #it "should link designation profile to designation account" do
      #@designation_account = create(:designation_account, organization: @org)
      #@designation_profile_account = @siebel.send(:link_profile_to_account, @designation_profile, @designation_account)
      #@designation_profile_account.designation_profile.id.should == @designation_profile.id
      #@designation_profile_account.designation_account.id.should == @designation_account.id
    #end
  #end

  #describe "import donors function" do

    #it "should import a household" do
      #@siebel.should_receive(:get_response).with(@org_account.remote_id, "donors").and_return { JSON.parse('[{"id":"000381188","accountName":"Gross,TimothyM\u0026Sandra","primary":{"id":"1-82-3430","firstName":"Timothy","preferredName":"Tim","middleName":"Merlin","lastName":"Gross","title":"Mr.","suffix":"","sex":"M","phoneNumbers":[{"type":"Home","primary":true,"phone":"970/304-1150"}]},"spouse":{"id":"1-82-3431","firstName":"Sandra","preferredName":"Sandy","middleName":"Louise","lastName":"Gross","title":"Mrs.","suffix":"","sex":"F","phoneNumbers":[{"type":"Home","primary":true,"phone":"970/304-1150"}]},"addresses":[{"type":"Mailing","primary":false,"seasonal":false,"address1":"9030E.LehighAve","address2":"","address3":"","address4":"","city":"Denver","state":"CO","zip":"80237"},{"type":"Mailing","primary":true,"seasonal":false,"address1":"162629thAve","address2":"","address3":"","address4":"","city":"Greeley","state":"CO","zip":"80634-5720"}],"type":"Household"}]') }
      #@siebel.should_receive(:add_or_update_donor_account)
      #primary_contact = double('contact')
      #@siebel.should_receive(:add_or_update_primary_contact).and_return(primary_contact)
      #@siebel.should_receive(:add_or_update_spouse)
      #primary_contact.should_receive(:add_spouse)
      #@siebel.import_donors
    #end

    #it "should import a church" do
      #@siebel.should_receive(:get_response).with(@org_account.remote_id, "donors").and_return { JSON.parse('[{"id":"000381188","accountName":"Gross,TimothyM\u0026Sandra","primary":{"id":"1-82-3430","firstName":"Timothy","preferredName":"Tim","middleName":"Merlin","lastName":"Gross","title":"Mr.","suffix":"","sex":"M","phoneNumbers":[{"type":"Home","primary":true,"phone":"970/304-1150"}]},"spouse":{"id":"1-82-3431","firstName":"Sandra","preferredName":"Sandy","middleName":"Louise","lastName":"Gross","title":"Mrs.","suffix":"","sex":"F","phoneNumbers":[{"type":"Home","primary":true,"phone":"970/304-1150"}]},"addresses":[{"type":"Mailing","primary":false,"seasonal":false,"address1":"9030E.LehighAve","address2":"","address3":"","address4":"","city":"Denver","state":"CO","zip":"80237"},{"type":"Mailing","primary":true,"seasonal":false,"address1":"162629thAve","address2":"","address3":"","address4":"","city":"Greeley","state":"CO","zip":"80634-5720"}],"type":"Church"}]') }
      #@siebel.should_receive(:add_or_update_donor_account)
      #@siebel.should_receive(:add_or_update_company)
      #@siebel.import_donors
    #end

    #it "should notify Airbrake when type is unknown" do
      #@person = create(:person)
      #@person.to_user.account_lists << create(:account_list)
      #@org_account.person = @person
      #@siebel.should_receive(:get_response).with(@org_account.remote_id, "donors").and_return { JSON.parse('[{"id":"437181698","accountName":"AvalonBaptistChurch","primary":{"id":"1-9Z-4206","firstName":"Lori","preferredName":"Lori","middleName":"","lastName":"Molloy","title":"Mrs.","suffix":"","sex":"Unspecified","phoneNumbers":[{"type":"Work","primary":true,"phone":"407/275-5499"}],"emailAddresses":[{"type":"Business","primary":true,"email":"lori@avalonchurch.org"}]},"addresses":[{"type":"Mailing","primary":false,"seasonal":false,"address1":"1921StoneAbbeyBlvd","address2":"","address3":"","address4":"","city":"Orlando","state":"FL","zip":"32825-4614"},{"type":"Mailing","primary":true,"seasonal":false,"address1":"13000AvalonLakeDrSte302","address2":"","address3":"","address4":"","city":"Orlando","state":"FL","zip":"32828-6451"},{"type":"Mailing","primary":false,"seasonal":false,"address1":"POBox780422","address2":"","address3":"","address4":"","city":"Orlando","state":"FL","zip":"32878-0422"}],"type":"Civilian"}]') }
      #Airbrake.should_receive(:notify)
      #@siebel.import_donors
    #end

    #it "should add or update primary contact" do
      #@siebel.should_receive(:add_or_update_person)
      #@siebel.send(:add_or_update_primary_contact, create(:account_list), @person, '', create(:donor_account))
    #end

    #it "should add or update spouse" do
      #@siebel.should_receive(:add_or_update_contact)
      #@siebel.send(:add_or_update_spouse, create(:account_list), @person, '', create(:donor_account))
    #end

    #describe "add_or_update_person method" do
      #before(:each) do
        #@account_list = create(:account_list)
        #@user = @person.to_user
        #@line = JSON.parse('{"id":"000408767","accountName":"Kocher,BrianEdward","primary":{"id":"1-86-235","firstName":"Brian","preferredName":"Brian","middleName":"Edward","lastName":"Kocher","title":"Mr.","suffix":"","sex":"M","phoneNumbers":[{"type":"Home","primary":true,"phone":"952/882-9435"}],"emailAddresses":[{"type":"Personal","primary":true,"email":"bekocher@comcast.net"}]},"addresses":[{"type":"Mailing","primary":false,"seasonal":false,"address1":"60135thAveS","address2":"","address3":"","address4":"","city":"Minneapolis","state":"MN","zip":"55419-2513"},{"type":"Mailing","primary":false,"seasonal":false,"address1":"60135thAve.S.","address2":"","address3":"","address4":"","city":"Minneapolis","state":"MN","zip":"55419"},{"type":"Mailing","primary":false,"seasonal":false,"address1":"1290516thAveS","address2":"","address3":"","address4":"","city":"Burnsville","state":"MN","zip":"55337-3736"},{"type":"Mailing","primary":false,"seasonal":false,"address1":"1290516thAveS","address2":"","address3":"","address4":"","city":"Burnsville","state":"MN","zip":"55337-3736"},{"type":"Mailing","primary":true,"seasonal":false,"address1":"445MoersCir","address2":"","address3":"","address4":"","city":"Chaska","state":"MN","zip":"55318-4609"}],"type":"Household"}')
        #@donor_account = create(:donor_account)
        #@master_person = create(:master_person)
        #@person = create(:person, master_person: @master_person)
        #@master_person_donor_account = create(:master_person_donor_account, 
                                              #master_person: @master_person,
                                              #donor_account: @donor_account)
      #end

      #it "shoud update primary details" do
        #@siebel.send(:add_or_update_person, @account_list, @user, @line, @donor_account, @master_person)
        #@person.reload
        #@person.first_name.should == 'Brian'
        #@person.last_name.should == 'Kocher'
        #@person.middle_name.should == 'Edward'
        #@person.title.should == 'Mr.'
        #@person.suffix.should == ''
      #end

      #it "shoud update phone numbers" do
        #@siebel.send(:add_or_update_person, @account_list, @user, @line, @donor_account, @master_person)
        #@person.reload
        #@person.phone_number.number.should == '9528829435'
        #@person.phone_number.location.should == 'Home'
        #@person.phone_number.primary.should == true
      #end

      #it "shoud update email address" do
        #@siebel.send(:add_or_update_person, @account_list, @user, @line, @donor_account, @master_person)
        #@person.reload
        #@person.email.email.should == 'bekocher@comcast.net'
      #end
    #end

    #describe "add_or_update_company method" do
      #before(:each) do
        #@user = @person.to_user
        #@line = JSON.parse('{"id":"000457337","accountName":"Langford,BrianE&Robin","primary":{"id":"1-86-2695","firstName":"Brian","preferredName":"Brian","middleName":"Eugene","lastName":"Langford","title":"Mr.","suffix":"","sex":"M","phoneNumbers":[{"type":"Home","primary":true,"phone":"517/351-9883"}],"emailAddresses":[{"type":"Business","primary":true,"email":"Brian.langford@uscm.org"}]},"spouse":{"id":"1-86-2694","firstName":"Robin","preferredName":"Robin","middleName":"Anne","lastName":"Langford","title":"Mrs.","suffix":"","sex":"F","phoneNumbers":[{"type":"Home","primary":true,"phone":"517/351-9883"}],"emailAddresses":[{"type":"Business","primary":true,"email":"Robin.langford@uscm.org"}]},"addresses":[{"type":"Mailing","primary":false,"seasonal":false,"address1":"1582W.Liberty","address2":"","address3":"","address4":"","city":"AnnArbor","state":"MI","zip":"48103"},{"type":"Mailing","primary":false,"seasonal":false,"address1":"1307KayPkwy","address2":"","address3":"","address4":"","city":"AnnArbor","state":"MI","zip":"48103"},{"type":"Mailing","primary":true,"seasonal":false,"address1":"1369RamblewoodDr","address2":"","address3":"","address4":"","city":"EastLansing","state":"MI","zip":"48823"}],"type":"Household"}')
        #@master_company = create(:master_company)
        #@company = create(:company, master_company: @master_company)
        #@company_position = create(:company_position, person: @person, company: @company)
        #@donor_account = create(:donor_account, master_company: @master_company)
        #@account_list = create(:account_list, creator: @user)
        #@user.account_lists << @account_list
      #end
      #it "should update phone numbers" do
        #@company = @siebel.send(:add_or_update_company, @account_list, @user, @line, @donor_account)
        #@company.phone_number.should == '517/351-9883'
      #end
      #it "shoud add a company with an existing master company" do
        #create(:company, name: 'Langford,BrianE&Robin')
        #-> {
          #@siebel.send(:add_or_update_company, @account_list, @user, @line, @donor_account)
        #}.should_not change(MasterCompany, :count)
      #end
      #it "shoud add a company without an existing master company and create a master company" do
        #-> {
          #@siebel.send(:add_or_update_company, @account_list, @user, @line, @donor_account)
        #}.should change(MasterCompany, :count).by(1)
      #end
      #it "shoud update an existing company" do
        #company = create(:company, name: 'Langford,BrianE&Robin')
        #@account_list.companies << company
        #-> {
          #new_company = @siebel.send(:add_or_update_company, @account_list, @user, @line, @donor_account)
          #new_company.should == company
        #}.should_not change(Company, :count)
      #end
      #it "shoud associate new company with the donor account" do
        #@siebel.send(:add_or_update_company, @account_list, @user, @line, @donor_account)
        #@donor_account.master_company_id.should_not be_nil
      #end
    #end
  #end

  #describe "import donations function" do
    #it "should raise error if start_date and end_date is nil" do
      #-> {
        #@siebel.import_donations
      #}.should raise_error(ArgumentError)
    #end
    #it "should import donations" do
      #@siebel.should_receive(:get_response).with(@org_account.remote_id, "donations").and_return {JSON.parse('[{"id":"YQN2T","amount":"25.00","designation":"0019171","donorId":"420765556","donationDate":"2008-04-20","paymentMethod":"CreditCard","paymentType":"MasterCard","channel":"Recurring","campaignCode":"102RS3C90"}]')  }
      #designation_account = double('designation_account')
      #@siebel.should_receive(:find_or_create_designation_account).and_return(designation_account)
      #@siebel.should_receive(:add_or_update_donation)
      #@siebel.import_donations("1/1/2000","12/31/2011")
    #end

    #describe "find_or_create_designation_account method" do
      #it "should get existing designation account" do
        #@number = "1234567"
        #@existing_designation_account = @siebel.send(:find_or_create_designation_account, @org_account, @number)
        #@existing_designation_account.designation_number.should == @number
      #end
      #it "should create designation account" do
        #@number = "9999999"
        #@org = double('organization')
        #@new_designation_account = @siebel.send(:find_or_create_designation_account, @org_account, @number)
        #@new_designation_account.designation_number.should == @number
      #end
      #it "should update designation account" do
        #@number = "1234567"
        #@extra = {name: 'Sample', balance: 100}
        #@new_designation_account = @siebel.send(:find_or_create_designation_account, @org, @number, @extra)
        #@new_designation_account.designation_number.should == @number
        #@new_designation_account.balance.should == 100
        #@new_designation_account.name.should == 'Sample'
      #end
    #end

    #describe "add_or_update_donation method" do
      #before(:each) do
        #@line = JSON.parse('{"id":"YQN2T","amount":"25.00","designation":"0019171","donorId":"420765556","donationDate":"2008-04-20","paymentMethod":"CreditCard","paymentType":"MasterCard","channel":"Recurring","campaignCode":"102RS3C90"}')
        #@designation_account = create(:designation_account)
        #@donor_account = create(:donor_account, account_number: @line['id'])
      #end
      #it "should update existing donation" do
        #@donation = create(:donation, 
                           #remote_id: @line['id'], 
                           #donor_account: @donor_account, 
                           #designation_account: @designation_account)
        #@siebel.send(:add_or_update_donation, @line, @designation_account, @org_account)
        #@donation.reload
        #@donation.motivation.should == '102RS3C90'
        #@donation.payment_method.should == 'CreditCard'
        #@donation.currency.should_not be nil
        #@donation.amount.should == 25.00
        #@donation.tendered_amount.should == 25.00
        #@donation.channel.should == "Recurring"
        #@donation.payment_type == "MasterCard"
      #end
      #it "should create donation" do
        #@donation = @siebel.send(:add_or_update_donation, @line, @designation_account, @org_account)
        #@donation.reload
        #@donation.motivation.should == '102RS3C90'
        #@donation.payment_method.should == 'CreditCard'
        #@donation.currency.should_not be nil
        #@donation.amount.should == 25.00
        #@donation.tendered_amount.should == 25.00
        #@donation.channel.should == "Recurring"
        #@donation.payment_type == "MasterCard"
      #end
    #end
  #end
end

