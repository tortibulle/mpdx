require 'spec_helper'

describe ContactSerializer do
  describe "contacts list" do
    let(:contact) { build(:contact) }
    subject{ ContactSerializer.new(contact).as_json[:contact] }

    describe "contact" do
      it { should include :id }
      it { should include :name }
      it { should include :pledge_amount }
      it { should include :pledge_frequency }
      it { should include :status }
      it { should include :notes }
    end
  end
end
