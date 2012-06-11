require 'spec_helper'

describe Activity do
  it "should return subject for to_s" do
    Activity.new(subject: 'foo').to_s.should == 'foo'
  end
end
