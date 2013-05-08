require 'spec_helper'

describe AccountListSerializer do
  let(:account_list) { build(:account_list) }
  subject { AccountListSerializer.new(account_list).as_json[:account_list] }

  it { should include :id }
  it { should include :name }
end