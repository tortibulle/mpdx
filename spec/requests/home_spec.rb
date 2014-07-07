require 'spec_helper'

describe 'Home' do
  before(:each) do
    @user = FactoryGirl.create(:user_with_account)
    login(@user)
  end

end
