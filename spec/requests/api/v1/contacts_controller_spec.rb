require 'spec_helper'
require_relative 'api_spec_helper'

describe Api::V1::ContactsController do
  describe 'when signed in' do
    let(:user) { create(:user_with_account) }
    let!(:contact) { create(:contact, account_list: user.account_lists.first) }
    let!(:person) { 
      p = create(:person)
      contact.people << p
      p
    }

    before do
      stub_auth
      get "/api/v1/contacts?access_token=" + user.access_token
    end
    let(:body) { JSON.parse(response.body) }

    it "responds 200" do
      response.code.should == "200"
    end

    it "contacts list" do 
      body.should include 'contacts'
    end
    describe "contact" do
      subject { body['contacts'][0] }
      it { should include 'id' }
      it { should include 'name' }
      it { should include 'pledge_amount' }
      it { should include 'pledge_frequency' }
      it { should include 'status' }
      it { should include 'notes' }
    end

    context "people" do
      it "list exists" do
        p person.contact
        body.should include 'people'
        body['people'].length.should > 0
      end
      describe "person" do
        subject { body['people'][0] }
        it { should include 'id' }
      end
    end
  end
end
