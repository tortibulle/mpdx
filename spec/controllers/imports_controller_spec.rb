require 'spec_helper'

describe ImportsController do
  before(:each) do
    @user = create(:user_with_account)
    sign_in(:user, @user)
    request.env['HTTP_REFERER'] = '/'
  end

  describe 'create' do
    it 'should handle a .csv upload for tnt' do
      @file = fixture_file_upload('/tnt_export.csv', 'text/csv')
      post :create, import: { file: @file, override: false, source: 'tnt' }
    end

    it 'should fail on a non .csv upload for tnt' do
      @file = fixture_file_upload('/tnt_export.txt', 'text/plain')
      post :create, import: { file: @file, override: false, source: 'tnt' }
    end
  end
end
