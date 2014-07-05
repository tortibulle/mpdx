require 'spec_helper'

describe CompanyPosition do
  it 'should return the position name for to_s' do
    CompanyPosition.new(position: 'foo').to_s.should == 'foo'
  end
end
