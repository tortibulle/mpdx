require 'spec_helper'

describe DesignationProfile do
  it 'should return name for to_s' do
    DesignationProfile.new(name: 'foo').to_s.should == 'foo'
  end
  it 'should return the first account when asked' do
    dp = FactoryGirl.create(:designation_profile)
    da = FactoryGirl.create(:designation_account)
    dp.designation_accounts << da
    dp.designation_account.should == da
  end
end
