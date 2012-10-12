require 'spec_helper'

describe MailChimpAccount do

  before(:each) do
    @account_list = create(:account_list)
    @account = MailChimpAccount.new(api_key: 'fake-us4')
    @account.account_list = @account_list
  end

  it "should return an array of lists" do
    stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=lists").
         with(:body => "%7B%22apikey%22%3A%22fake-us4%22%7D").
         to_return(:body => '{"total":2,"data":[{"id":"1e72b58b72","web_id":97593,"name":"MPDX","date_created":"2012-10-09 13:50:12","email_type_option":false,"use_awesomebar":true,"default_from_name":"MPDX","default_from_email":"support@mpdx.org","default_subject":"","default_language":"en","list_rating":3,"subscribe_url_short":"http:\/\/eepurl.com\/qnY35","subscribe_url_long":"http:\/\/26am.us4.list-manage1.com\/subscribe?u=720971c5830c5228bdf461524&id=1e72b58b72","beamer_address":"NzIwOTcxYzU4MzBjNTIyOGJkZjQ2MTUyNC1iYmNlYzBkNS05ZDhlLTQ5NDctYTg1OC00ZjQzYTAzOGI3ZGM=@campaigns.mailchimp.com","visibility":"pub","stats":{"member_count":159,"unsubscribe_count":0,"cleaned_count":0,"member_count_since_send":159,"unsubscribe_count_since_send":0,"cleaned_count_since_send":0,"campaign_count":0,"grouping_count":1,"group_count":4,"merge_var_count":2,"avg_sub_rate":null,"avg_unsub_rate":null,"target_sub_rate":null,"open_rate":null,"click_rate":null},"modules":[]},{"id":"29a77ba541","web_id":97493,"name":"Newsletter","date_created":"2012-10-09 00:32:44","email_type_option":true,"use_awesomebar":true,"default_from_name":"Josh Starcher","default_from_email":"josh.starcher@cru.org","default_subject":"","default_language":"en","list_rating":0,"subscribe_url_short":"http:\/\/eepurl.com\/qmAWn","subscribe_url_long":"http:\/\/26am.us4.list-manage.com\/subscribe?u=720971c5830c5228bdf461524&id=29a77ba541","beamer_address":"NzIwOTcxYzU4MzBjNTIyOGJkZjQ2MTUyNC02ZmZiZDJhOS0zNWFmLTQ1YzQtOWE0ZC1iOTZhMmRlMTQ0ZDc=@campaigns.mailchimp.com","visibility":"pub","stats":{"member_count":75,"unsubscribe_count":0,"cleaned_count":0,"member_count_since_send":75,"unsubscribe_count_since_send":0,"cleaned_count_since_send":0,"campaign_count":0,"grouping_count":1,"group_count":3,"merge_var_count":2,"avg_sub_rate":null,"avg_unsub_rate":null,"target_sub_rate":null,"open_rate":null,"click_rate":null},"modules":[]}]}')
    @account.lists.length.should == 2
  end

  it "should find a list by list_id" do
    @account.stub(:lists).and_return([OpenStruct.new(id: 1, name: 'foo')])
    @account.list(1).name.should == 'foo'
  end

  it "should find the primary list" do
    @account.stub(:lists).and_return([OpenStruct.new(id: 1, name: 'foo')])
    @account.primary_list_id = 1
    @account.primary_list.name.should == 'foo'
  end

  it "should deactivate the account if the api key is invalid" do
    stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=lists").
         with(:body => "%7B%22apikey%22%3A%22fake-us4%22%7D").
         to_return(:body => '{"error":"Invalid Mailchimp API Key: fake-us4","code":104}')
    @account.active = true
    @account.validate_key
    @account.active.should == false
  end

  it "should activate the account if the api key is valid" do
    stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=lists").
         with(:body => "%7B%22apikey%22%3A%22fake-us4%22%7D").
         to_return(:body => '{"total":2,"data":[{"id":"1e72b58b72","web_id":97593,"name":"MPDX","date_created":"2012-10-09 13:50:12","email_type_option":false,"use_awesomebar":true,"default_from_name":"MPDX","default_from_email":"support@mpdx.org","default_subject":"","default_language":"en","list_rating":3,"subscribe_url_short":"http:\/\/eepurl.com\/qnY35","subscribe_url_long":"http:\/\/26am.us4.list-manage1.com\/subscribe?u=720971c5830c5228bdf461524&id=1e72b58b72","beamer_address":"NzIwOTcxYzU4MzBjNTIyOGJkZjQ2MTUyNC1iYmNlYzBkNS05ZDhlLTQ5NDctYTg1OC00ZjQzYTAzOGI3ZGM=@campaigns.mailchimp.com","visibility":"pub","stats":{"member_count":159,"unsubscribe_count":0,"cleaned_count":0,"member_count_since_send":159,"unsubscribe_count_since_send":0,"cleaned_count_since_send":0,"campaign_count":0,"grouping_count":1,"group_count":4,"merge_var_count":2,"avg_sub_rate":null,"avg_unsub_rate":null,"target_sub_rate":null,"open_rate":null,"click_rate":null},"modules":[]},{"id":"29a77ba541","web_id":97493,"name":"Newsletter","date_created":"2012-10-09 00:32:44","email_type_option":true,"use_awesomebar":true,"default_from_name":"Josh Starcher","default_from_email":"josh.starcher@cru.org","default_subject":"","default_language":"en","list_rating":0,"subscribe_url_short":"http:\/\/eepurl.com\/qmAWn","subscribe_url_long":"http:\/\/26am.us4.list-manage.com\/subscribe?u=720971c5830c5228bdf461524&id=29a77ba541","beamer_address":"NzIwOTcxYzU4MzBjNTIyOGJkZjQ2MTUyNC02ZmZiZDJhOS0zNWFmLTQ1YzQtOWE0ZC1iOTZhMmRlMTQ0ZDc=@campaigns.mailchimp.com","visibility":"pub","stats":{"member_count":75,"unsubscribe_count":0,"cleaned_count":0,"member_count_since_send":75,"unsubscribe_count_since_send":0,"cleaned_count_since_send":0,"campaign_count":0,"grouping_count":1,"group_count":3,"merge_var_count":2,"avg_sub_rate":null,"avg_unsub_rate":null,"target_sub_rate":null,"open_rate":null,"click_rate":null},"modules":[]}]}')
    @account.active = false
    @account.validate_key
    @account.active.should == true
  end

  it "should return the datacenter for an api key" do
    @account.datacenter.should == 'us4'
  end

  describe "queueing methods" do

    before do
      ResqueSpec.reset!
      @account.save!
    end

    it "should queue subscribe_contacts" do
      @account.queue_export_to_primary_list
      MailChimpAccount.should have_queued(@account.id, :subscribe_contacts)
    end

    it "should queue subscribe_contacts for one contact" do
      contact = create(:contact)
      @account.queue_subscribe_contact(contact)
      MailChimpAccount.should have_queued(@account.id, :subscribe_contacts, contact.id)
    end

    it "should queue subscribe_person" do
      person = create(:person)
      @account.queue_subscribe_person(person)
      MailChimpAccount.should have_queued(@account.id, :subscribe_person, person.id)
    end

    it "should queue unsubscribe_email" do
      @account.queue_unsubscribe_email('foo@example.com')
      MailChimpAccount.should have_queued(@account.id, :unsubscribe_email, 'foo@example.com')
    end

    it "should queue update_email" do
      @account.queue_update_email('foo@example.com', 'foo1@example.com')
      MailChimpAccount.should have_queued(@account.id, :update_email, 'foo@example.com', 'foo1@example.com')
    end

    it "should queue unsubscribe_email for each of a contacts email addresses" do
      contact = create(:contact)
      contact.people << create(:person)

      2.times { |i| contact.people.first.email_addresses << EmailAddress.new(email: "foo#{i}@example.com") }

      @account.queue_unsubscribe_contact(contact)
      MailChimpAccount.should have_queued(@account.id, :unsubscribe_email, 'foo0@example.com')
      MailChimpAccount.should have_queued(@account.id, :unsubscribe_email, 'foo1@example.com')
    end

  end

  describe "callbacks" do
    it "should queue import if primary list changed" do
      @account.should_receive(:queue_export_to_primary_list).and_return(true)
      @account.primary_list_id = 'foo'
      @account.save
    end
  end

  context "when updating mailchimp" do
    it "should update an email" do
      stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=listUpdateMember").
        to_return(body: '{}')
      @account.send(:update_email, 'foo@example.com', 'foo1@example.com')
    end

    it "should unsubscribe an email" do
      stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=listUnsubscribe").
        to_return(body: '{}')
      @account.send(:unsubscribe_email, 'foo@example.com')
    end


    context "subscribing a person" do
      it "should add a person's primary email address" do
        stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=listSubscribe").
          to_return(body: '{}')
        person = create(:person, email: 'foo@example.com')
        @account.send(:subscribe_person, person.id)
      end
    end

    context "subscribing contacts" do
      it "should subscribe a single contact" do
        contact = create(:contact, send_newsletter: 'Email', account_list: @account_list)
        contact.people << create(:person, email: 'foo@example.com')

        @account.should_receive(:export_to_list).with(@account.primary_list_id, [contact].to_set).and_return(true)
        @account.send(:subscribe_contacts, contact.id)
      end

      it "should subscribe multiple contacts" do
        contact1 = create(:contact, send_newsletter: 'Email', account_list: @account_list)
        contact1.people << create(:person, email: 'foo@example.com')

        contact2 = create(:contact, send_newsletter: 'Email', account_list: @account_list)
        contact2.people << create(:person, email: 'foo@example.com')

        @account.should_receive(:export_to_list).with(@account.primary_list_id, [contact1, contact2].to_set).and_return(true)
        @account.send(:subscribe_contacts, [contact1.id, contact2.id])
      end

      it "should subscribe all contacts" do
        contact = create(:contact, send_newsletter: 'Email', account_list: @account_list)
        contact.people << create(:person, email: 'foo@example.com')

        @account.should_receive(:export_to_list).with(@account.primary_list_id, [contact].to_set).and_return(true)
        @account.send(:subscribe_contacts)
      end

      it "should export to a list" do
        stub_request(:post, "https://us4.api.mailchimp.com/1.3/?method=listBatchSubscribe").
         with(:body => "%7B%22apikey%22%3A%22fake-us4%22%2C%22id%22%3Anull%2C%22batch%22%3A%5B%7B%22EMAIL%22%3A%22foo%40example.com%22%2C%22FNAME%22%3A%22John%22%2C%22LNAME%22%3Anull%2C%22GROUPINGS%22%3A%5B%7B%22id%22%3Anull%2C%22groups%22%3A%22Partner+-+Pray%22%7D%5D%7D%5D%2C%22update_existing%22%3Atrue%2C%22double_optin%22%3Afalse%2C%22send_welcome%22%3Afalse%2C%22replace_interests%22%3Atrue%7D").
         to_return(:status => 200, :body => "{}", :headers => {})

        contact = create(:contact, send_newsletter: 'Email', account_list: @account_list)
        contact.people << create(:person, email: 'foo@example.com')

        @account.send(:export_to_list, @account.primary_list_id, [contact])
      end

      context "adding status groups" do
        before do
          @gb = double
          @account.stub(:gb).and_return(@gb)
        end
        it "should add groups to an existing grouping" do
          @account.grouping_id = 1

          list_id = 'foo'

          @gb.should_receive(:list_interest_groupings).with(id: list_id).and_return([{'id' => 1, 'name' => 'Partner Status', 'groups' => []}])

          @gb.should_receive(:list_interest_grouping_update).with(grouping_id: 1, name: 'type', value: 'hidden')

          @gb.should_receive(:list_interest_group_add).with({id: 'foo', group_name: 'Partner - Pray', grouping_id: 1})

          @account.send(:add_status_groups, list_id, ['Partner - Pray'])
        end

        it "should create a new grouping if none exists" do
          list_id = 'foo'

          @gb.should_receive(:list_interest_groupings).with(id: list_id).and_return([])

          @gb.should_receive(:list_interest_grouping_add).with({:id=>"foo", :name=>"Partner Status", :type=>"hidden", :groups=>["Partner - Pray"]})

          @account.send(:add_status_groups, list_id, ['Partner - Pray'])
        end

      end
    end

  end

end
