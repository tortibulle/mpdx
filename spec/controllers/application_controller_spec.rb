require 'spec_helper'

describe ApplicationController do
  describe "After log out" do
    it "redirects to login" do
      controller.send(:after_sign_out_path_for, @user).should == login_url
    end
    it "redirects to relay" do
      @request.session[:signed_in_with] = 'relay'
      controller.send(:after_sign_out_path_for, @user).should == "https://signin.relaysso.org/cas/logout?service=#{login_url}"
    end
    it "redirects to key" do
      @request.session[:signed_in_with] = 'key'
      controller.send(:after_sign_out_path_for, @user).should == "https://thekey.me/cas/logout?service=#{login_url}"
    end
  end
end
