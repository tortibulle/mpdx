require "spec_helper"

describe HelpRequestMailer do
  describe "email" do
    let(:help_request) { build(:help_request) }
    let(:mail) { HelpRequestMailer.email(help_request) }

    it "renders the headers" do
      mail.subject.should eq("Email")
      mail.to.should eq(["support@mpdx.org"])
      mail.from.should eq([help_request.email])
    end
  end

end
