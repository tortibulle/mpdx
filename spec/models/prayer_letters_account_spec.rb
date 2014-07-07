require 'spec_helper'

describe PrayerLettersAccount do
  context '#get_response' do
    it 'marks token as invalid if response is a 401' do
      stub_request(:get, %r{https:\/\/www\.prayerletters\.com\/*})
        .to_return(status: 401)

      pla = create(:prayer_letters_account)

      pla.should_receive(:handle_bad_token).and_return('{}')

      pla.contacts
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
