require 'spec_helper'
describe AccountListExhibit do

  subject { AccountListExhibit.new(account_list, context) }
  let(:account_list) { build(:account_list) }
  let(:context) { double }
  let(:user) { create(:user) }

  before do
    2.times do
      account_list.designation_accounts << build(:designation_account)
    end
    account_list.users << user
  end

  it "returns a designation account names for to_s" do
    subject.to_s.should == account_list.designation_accounts.collect(&:name).join(', ')
  end

  it 'returns names with balances' do
    account_list.stub!(:designation_accounts).and_return([create(:designation_account, name: 'foo', balance: '5')])
    context.stub!(:number_to_current_currency).with(5).and_return('$5')
    subject.balances(user).should == "<div class=\"account_balances lots\">Balance: $5</div>"
  end

  it "converts null balances to 0" do
    account_list.stub!(:designation_accounts).and_return([create(:designation_account, name: 'foo', balance: nil)])
    context.stub!(:number_to_current_currency).with(0).and_return('$0')
    subject.balances(user).should == "<div class=\"account_balances lots\">Balance: $0</div>"
  end

  it "sums the balances of multiple designation accounts" do
    account_list.stub!(:designation_accounts).and_return([create(:designation_account, name: 'foo', balance: 1),
                                                          create(:designation_account, name: 'bar', balance: 2)])
    context.stub!(:number_to_current_currency).with(3).and_return('$3')
    subject.balances(user).should == "<div class=\"account_balances lots\">Balance: $3</div>"
  end

end


