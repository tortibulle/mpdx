require 'spec_helper'
describe Exhibit do

  subject { Exhibit.new(OpenStruct.new, context) }
  let(:context) { double }

  it "shouldn't be applicable to anything" do
    Exhibit.applicable_to?(nil).should == false
  end

  it "should return the decorated model" do
    subject.to_model.should == OpenStruct.new
  end

  it "should return the decorated class" do
    subject.class.should == OpenStruct
  end

end
