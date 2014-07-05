require 'spec_helper'

describe Api::V1::TasksController do
  describe 'api' do
    let(:user) { create(:user_with_account) }

    before do
      create(:task, account_list: user.account_lists.first, start_at: Time.now.end_of_day + 1.day)
      create(:task, account_list: user.account_lists.first, start_at: Time.now.beginning_of_day - 1.day)
      create(:task, account_list: user.account_lists.first, completed: true, start_at: Time.now.end_of_day + 1.day)
      create(:task, account_list: user.account_lists.first, completed: true, start_at: Time.now.beginning_of_day - 1.day)
    end

    it 'gets count' do
      get :count, access_token: user.access_token
      response.should be_success
      json = JSON.parse(response.body)
      json['total'].should == 4
      json['uncompleted'].should == 2
      json['overdue'].should == 1
    end
  end
end
