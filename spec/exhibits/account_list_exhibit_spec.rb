require 'spec_helper'
describe AccountListExhibit do

  subject { AccountListExhibit.new(account_list, context) }
  let(:account_list) { build(:account_list) }
  let(:context) { double }

  before do
    2.times do
      account_list.designation_accounts << build(:designation_account)
    end
  end

  it "returns a designation account names for to_s" do
    subject.to_s.should == account_list.designation_accounts.collect(&:name).join(', ')
  end

  it 'returns names with balances' do
    account_list.stub!(:designation_accounts).and_return([create(:designation_account, name: 'foo', balance: '5')])
    context.stub!(:number_to_current_currency).and_return('$5')
    subject.balances.should == "<div class=\"account_balances lots\">Balance: $5</div>"
  end

end


