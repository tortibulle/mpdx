require 'spec_helper'

describe MailChimpAccount do
  before(:each) do
    @account = MailChimpAccount.new(api_key: 'fake-us4')
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
      @account.account_list = create(:account_list)
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

    it "should queue unsubscribe_email for each of a contacts email addresses" do
      contact = create(:contact)
      contact.people << create(:person)

      2.times { |i| contact.people.first.email_addresses << EmailAddress.new(email: "foo#{i}@example.com") }

      @account.queue_unsubscribe_contact(contact)
      MailChimpAccount.should have_queued(@account.id, :unsubscribe_email, 'foo0@example.com')
      MailChimpAccount.should have_queued(@account.id, :unsubscribe_email, 'foo1@example.com')
    end

  end

end
