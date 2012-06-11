require 'spec_helper'
describe PhoneNumberExhibit do

  subject { PhoneNumberExhibit.new(phone_number, context) }
  let(:phone_number) { build(:phone_number, number: '1234567890', country_code: '1')}
  let(:context) { double }

  it "returns a formatted number" do
    context.stub!(:number_to_phone).and_return('(123) 456-7890')
    subject.number.should == '(123) 456-7890'
  end

  it "should return unformatted number if we don't know what kind of number it is" do
    phone_number.number = '555'
    phone_number.country_code = '2'
    subject.number.should == '555'
  end

end
