require 'spec_helper'

describe UserSerializer do
  let(:user) { create(:user_with_account) }
  subject { UserSerializer.new(user).as_json }

  it { should include :account_lists }
end
