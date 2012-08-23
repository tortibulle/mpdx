require "spec_helper"

describe FacebookImportMailer do
  describe "complete" do
    let(:mail) { FacebookImportMailer.complete }

    it "renders the headers" do
      mail.subject.should eq("Complete")
      mail.to.should eq(["to@example.org"])
      mail.from.should eq(["from@example.com"])
    end

    it "renders the body" do
      mail.body.encoded.should match("Hi")
    end
  end

end
