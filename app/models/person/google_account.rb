require 'google/api_client'
require 'gmail'
class Person::GoogleAccount < ActiveRecord::Base
  include Person::Account

  has_many :google_integrations, foreign_key: :google_account_id, dependent: :destroy

  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.google_accounts
    Rails.logger.debug(auth_hash)
    creds = auth_hash.credentials
    @remote_id = auth_hash.uid
    expires_at = creds.expires ? Time.at(creds.expires_at) : nil
    @attributes = {
      remote_id: @remote_id,
      token: creds.token,
      refresh_token: creds.refresh_token,
      expires_at: expires_at,
      email: auth_hash.info.email,
      valid_token: true
    }
    super
  end

  def self.create_user_from_auth(_auth_hash)
    fail Person::Account::NoSessionError, 'Somehow a user without an account/session is trying to sign in using google'
  end

  def google_integration(account_list_id)
    google_integrations.find_by(account_list_id: account_list_id)
  end

  def to_s
    email
  end

  def self.one_per_user?() false; end

  def token_expired?
    expires_at < Time.now
  end

  def import_emails(account_list)
    since = last_email_sync || 30.days.ago

    gmail do |g|
      # loop through all contacts, logging email addresses
      account_list.contacts.each do |contact|
        contact.people.each do |person|
          person.email_addresses.collect(&:email).uniq.each do |email|
            # sent emails
            sent = g.mailbox("[Gmail]/Sent Mail")
            sent.emails(to: email, after: since).each do |gmail_message|
              log_email(gmail_message, account_list, contact, person, 'Done')
            end

            # received emails
            all = g.mailbox("[Gmail]/All Mail")
            all.emails(from: email, after: since).each do |gmail_message|
              log_email(gmail_message, account_list, contact, person, 'Received')
            end
          end
        end
      end
    end
    update_attributes(last_email_sync: Time.now)
  end

  def log_email(gmail_message, account_list, contact, person, result)
    if gmail_message.message.multipart?
      message = gmail_message.message.text_part.body.decoded
    else
      message = gmail_message.message.body.decoded
    end
    task = contact.tasks.create!(subject: gmail_message.subject,
                                start_at: gmail_message.envelope.date,
                                completed: true,
                                completed_at: gmail_message.envelope.date,
                                account_list_id: account_list.id,
                                activity_type: 'Email',
                                result: result)
    task.activity_comments.create!(body: message, person: person)
  end

  def gmail
    refresh_token! if token_expired?

    begin
      client = Gmail.connect(:xoauth2, email, token)
      yield client
    ensure
      client.logout
    end
  end

  def client
    unless @client
      @client = Google::APIClient.new(application_name: 'MPDX', application_version: '1.0')
      @client.authorization.access_token = token
    end
    @client
  end

  def plus
    @plus ||= client.discovered_api('plus')
  end

  def imap
    refresh_token! if token_expired?

    unless @imap
      @imap = Net::IMAP.new('imap.gmail.com', 993, usessl = true, certs = nil, verify = false)
      @imap.authenticate('XOAUTH2', email, token)
    end
    @imap
  end

  def token_expired?
    expires_at < Time.now
  end

  def contacts
    refresh_token! if token_expired?

    unless @contacts
      client = OAuth2::Client.new(APP_CONFIG['google_key'], APP_CONFIG['google_secret'])
      oath_token = OAuth2::AccessToken.new(client, token)
      contact_user = GoogleContactsApi::User.new(oath_token)
      @contacts = contact_user.contacts
    end
    @contacts
  end

  def client
    refresh_token! if token_expired?

    unless @client
      @client = Google::APIClient.new(application_name: 'MPDX', application_version: '1.0')
      @client.authorization.access_token = token
    end
    @client
  end

  def refresh_token!
    fail MissingRefreshToken, 'No refresh token' if refresh_token.blank?

    # Refresh auth token from google_oauth2.
    params = {
      client_id: APP_CONFIG['google_key'],
      client_secret: APP_CONFIG['google_secret'],
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    }
    RestClient.post('https://accounts.google.com/o/oauth2/token', params, content_type: 'application/x-www-form-urlencoded') {|response, _request, _result, &_block|
      json = JSON.parse(response)
      if response.code == 200
        self.token = json['access_token']
        self.expires_at = 59.minutes.from_now
        save
      else
        case json['error']
        when 'invalid_grant'
          fail MissingRefreshToken, 'Invalid Grant'
        else
          fail response.inspect
        end
      end
    }
  end

  class MissingRefreshToken < StandardError
  end
end
