require 'spec_helper'

describe CredentialValidator do
  before(:each) do
    @record = FactoryGirl.build(:organization_account)
    @validator = CredentialValidator.new({})
  end

  describe 'when using requires username and password' do
    before(:each) do
      @record.stub(:requires_username_and_password?) {true}
    end

    it "should not add error if the record is missing an org" do
      @record.organization = nil
      @record.valid?
      @record.errors.full_messages.should_not include(_('Your username and password for %{org} are invalid.').localize % {org: @record.organization})
    end

    it "should not add error if the record is missing username" do
      @record.username = nil
      @record.valid?
      @record.errors.full_messages.should_not include(_('Your username and password for %{org} are invalid.').localize % {org: @record.organization})
    end

    it "should add error if the record is missing password" do
      @record.password = nil
      @record.valid?
      @record.errors.full_messages.should_not include(_('Your username and password for %{org} are invalid.').localize % {org: @record.organization})
    end

    it "should add error if the username and password are invalid" do
      @api = FakeApi.new
      @record.organization.stub(:api) {@api}
      @api.stub(:validate_username_and_password) {false}
      @validator.validate(@record)
      @record.errors.full_messages.should == [_('Your username and password for %{org} are invalid.').localize % {org: @record.organization}]
    end

  end

  describe 'when username and password is not required' do
    before(:each) do
      @record.stub(:requires_username_and_password?) {false}
    end

    it "should not add error if the username and password are blank" do
      @record.username = nil
      @record.password = nil
      @validator.validate(@record)
      @record.errors.full_messages.should_not include(_('Your username and password for %{org} are invalid.').localize % {org: @record.organization})
    end
  end

end
