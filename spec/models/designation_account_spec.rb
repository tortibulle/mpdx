require 'spec_helper'

describe DesignationAccount do
  it 'should return designation_number for to_s' do
    DesignationAccount.new(designation_number: 'foo').to_s.should == 'foo'
  end

  it "should return a user's first account list" do
    account_list = double('account_list')
    user = double('user', account_lists: [account_list])
    da = DesignationAccount.new
    da.stub(:account_lists).and_return([account_list])
    da.account_list(user).should == account_list
  end
end
