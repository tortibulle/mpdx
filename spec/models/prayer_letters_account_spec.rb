require 'spec_helper'

describe PrayerLettersAccount do
  context '#get_response' do

    it 'marks token as invalid if response is a 401 for OAuth2' do
      stub_request(:get, %r{https:\/\/www\.prayerletters\.com\/*}).to_return(status: 401)
      pla = create(:prayer_letters_account_oauth2)
      pla.should_receive(:handle_bad_token).and_return('{}')
      pla.contacts
    end

    it 'uses OAuth2 if possible' do
      stub_request(:get, 'https://www.prayerletters.com/api/v1/contacts')
        .with(headers: { 'Authorization' => 'Bearer test_oauth2_token' })
        .to_return(body: '{}')
      pla_oauth2 = create(:prayer_letters_account_oauth2)
      pla_oauth2.contacts
    end

    it 'uses OAuth1 if no oauth2_token present' do
      stub_request(:get, 'https://www.prayerletters.com/api/v1/contacts')
        .to_return(body: '{}')
      pla_oauth1 = create(:prayer_letters_account)
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
end
