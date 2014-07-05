require 'spec_helper'

describe Organization do
  it 'should return the org name for to_s' do
    Organization.new(name: 'foo').to_s.should == 'foo'
  end
end
