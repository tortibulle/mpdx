require 'spec_helper'

describe 'Contacts Filters' do
  before(:all) do
    @user = FactoryGirl.create(:user_with_account)
    login(@user)
  end
  describe 'GET /contacts' do
    it 'can filter on cities' do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get contacts_path(city: %w(foo bar))
      response.status.should be(200)
    end
  end
end
