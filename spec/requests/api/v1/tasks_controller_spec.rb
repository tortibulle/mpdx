require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::TasksController do
  describe 'api' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first) }
    let!(:task1) { create(:task, account_list: user.account_lists.first) }
    let!(:task2) { create(:task, account_list: user.account_lists.first) }

    before do
      contact.tasks << task1
      stub_auth
    end

    it "all tasks should return all tasks" do
      get "/api/v1/tasks?access_token=" + user.access_token
      response.should be_success
      JSON.parse(response.body)['tasks'].length.should == 2
    end

    it "contact tasks should return one task" do
      get "/api/v1/tasks?filters[contact_ids]="+contact.id.to_s+"&access_token=" + user.access_token
      response.should be_success
      JSON.parse(response.body)['tasks'].length.should == 1
    end
  end
end
