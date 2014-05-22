require 'spec_helper'

describe AccountListSerializer do
  let(:account_list) { build(:account_list) }
  subject { AccountListSerializer.new(account_list).as_json[:account_list] }

  it { should include :id }
  it { should include :name }

  # describe "when changing contact pledge" do
  #   it "should change cache_key" do
  #     contact = create(:contact, account_list: account_list)
  #     contact.update_attributes(:pledge_amount => 50, :status => 'Partner - Financial')
  #     serializer = AccountListSerializer.new(account_list)
  #     old_key = serializer.cache_key
  #     contact.update_attributes(:pledge_amount => 100)
  #     AccountListSerializer.new(AccountList.find(account_list)).cache_key.should_not eq old_key
  #   end
  # end
end