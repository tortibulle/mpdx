require 'google/api_client'
require 'gmail'
class Person::GoogleAccount < ActiveRecord::Base
  extend Person::Account

  # attr_accessible :email

  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.google_accounts
    creds = auth_hash.credentials
    @remote_id = auth_hash.uid
    expires_at = creds.expires ? Time.at(creds.expires_at) : nil
    @attributes = {
      remote_id: @remote_id,
      token: creds.token,
      refresh_token: creds.refresh_token,
      expires_at: expires_at,
      email: auth_hash.info.email,
      valid_token: true}
    super
  end

  def to_s
    email
  end

  def self.one_per_user?() false; end

  def queue_import_data

  end

  def import_emails(account_list)
    since = last_email_sync || 30.days.ago

    gmail do |g|
      # loop through all contacts, logging email addresses
      email_addresses = []
      account_list.contacts.active.includes(people: :email_addresses).each do |contact|
        contact.people.each do |person|
          person.email_addresses.collect(&:email).uniq.each do |email|
            unless email_addresses.include?(email)
              email_addresses << email

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
    task.activity_comments.create!(body: message.to_s.unpack("C*").pack("U*").force_encoding("UTF-8").encode!, person: person)
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

  def plus_api
    @plus_api ||= client.discovered_api('plus')
  end

  def calendar_api
    @calendar_api ||= client.discovered_api('calendar', 'v3')
  end

  def calendars
    result = client.execute(
      :api_method => calendar_api.calendar_list.list,
      :parameters => {'userId' => 'me'}
    )
    calendar_list = result.data
    calendar_list.items.detect_all {|c| c.accessRole == 'owner'}
  end

  def imap
    refresh_token! if token_expired?

    unless @imap
      @imap = Net::IMAP.new('imap.gmail.com', 993, usessl = true, certs = nil, verify = false)
      @imap.authenticate('XOAUTH2', email, token)
    end
    @imap
  end

  def folders
    @folders ||= imap.list '/', '*'
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

  def refresh_token!
    raise 'No refresh token' if refresh_token.blank?

    # Refresh auth token from google_oauth2.
    params = {
        client_id: APP_CONFIG['google_key'],
        client_secret: APP_CONFIG['google_secret'],
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
    }
    RestClient.post('https://accounts.google.com/o/oauth2/token', params, content_type: 'application/x-www-form-urlencoded') {|response, request, result, &block|
      if response.code == 200
        ap response
        json = JSON.parse(response)
        self.token = json['access_token']
        self.expires_at = 59.minutes.from_now
        save
      else
        raise response.inspect
      end
    }
  end

end
