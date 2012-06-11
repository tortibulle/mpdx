require 'spec_helper'
describe DonationExhibit do

  subject { DonationExhibit.new(donation, context) }
  let(:donation) { build(:donation, amount: '1.23', currency: 'USD')}
  let(:context) { double }

  it "returns a formatted amount" do
    context.stub!(:number_to_current_currency).and_return('$1.23')
    subject.amount.should == '$1.23'
  end

end

