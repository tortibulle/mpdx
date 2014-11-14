require 'spec_helper'

describe PrayerLettersAccount do
  context '#get_response' do
    def test_marks_token_invalid(pla)
      stub_request(:get, %r{https:\/\/www\.prayerletters\.com\/*}).to_return(status: 401)
      pla.should_receive(:handle_bad_token).and_return('{}')
      pla.contacts
    end

    it 'marks token as invalid if response is a 401 for OAuth1' do
      test_marks_token_invalid(create(:prayer_letters_account))
    end

    it 'marks token as invalid if response is a 401 for OAuth2' do
      test_marks_token_invalid(create(:prayer_letters_account_oauth2))
    end

    it 'uses OAuth2 if possible' do
      stub_request(:get, 'https://www.prayerletters.com/api/v1/contacts')
        .with(headers: { 'Authorization' => 'Bearer test_oauth2_token' })
        .to_return(body: '{}')
      pla_oauth2 = create(:prayer_letters_account_oauth2)
      pla_oauth2.contacts
      expect(PrayerLettersOAuthUpgrader).to receive(:perform_async).exactly(0).times
    end

    it 'uses OAuth1 and queues upgrade if no oauth2_token present' do
      stub_request(:get, %r{https://www.prayerletters.com/api/v1/contacts\?oauth_nonce=.*&oauth_signature=.*&oauth_signature_method=HMAC-SHA1&oauth_timestamp=.*&oauth_token=MyString&oauth_version=1.0})
        .to_return(body: '{}')
      pla_oauth1 = create(:prayer_letters_account)
      expect(PrayerLettersOAuthUpgrader).to receive(:perform_async)
      pla_oauth1.contacts
    end
  end

  context '#handle_bad_token' do
    let(:pla) { create(:prayer_letters_account) }

    it 'sends an email to the account users' do
      AccountMailer.should_receive(:prayer_letters_invalid_token).with(an_instance_of(AccountList)).and_return(double(deliver: true))

      expect {
        pla.handle_bad_token
      }.to raise_exception(PrayerLettersAccount::AccessError)
    end

    it 'sets valid_token to false' do
      AccountMailer.stub(:prayer_letters_invalid_token).and_return(double(deliver: true))

      expect {
        pla.handle_bad_token
      }.to raise_exception(PrayerLettersAccount::AccessError)

      expect(pla.valid_token).to be_false
    end
  end

  context '#upgrade_to_oauth2' do
    it 'makes a request to prayerletters.com with OAuth1 to get an OAuth2 token' do
      stub_request(:get, %r{https://www.prayerletters.com/api/oauth1/v2migration\?oauth_nonce=.*&oauth_signature=.*&oauth_signature_method=HMAC-SHA1&oauth_timestamp=.*&oauth_token=MyString&oauth_version=1.0})
        .to_return(body: '{ "access_token": "test_token"}')
      pla_oauth1 = create(:prayer_letters_account)
      pla_oauth1.upgrade_to_oauth2
      expect(pla_oauth1.oauth2_token).to eq('test_token')
    end
  end
end
