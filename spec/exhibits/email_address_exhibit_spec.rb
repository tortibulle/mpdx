require 'spec_helper'
describe EmailAddressExhibit do

  subject { EmailAddressExhibit.new(email_address, context) }
  let(:email_address) { build(:email_address) }
  let(:context) { double }

  it 'returns a mailto link for to_s' do
    context.stub(:mail_to).and_return('<a href="mailto:MyString">MyString</a>')
    subject.to_s.should == '<a href="mailto:MyString">MyString</a>'
  end

end
