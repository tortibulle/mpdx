require 'google/api_client'
class Person::GoogleAccount < ActiveRecord::Base
  include Person::Account

  has_many :google_integrations, foreign_key: :google_account_id, dependent: :destroy
  has_many :google_emails, foreign_key: :google_account_id
  has_many :google_contacts, foreign_key: :google_account_id

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

  def contacts
    @contacts ||= contacts_api_user.contacts
  end

  def contact_groups
    @contact_groups ||= contacts_api_user.groups
  end

  def contacts_for_group(group_id)
    GoogleContactsApi::Group.new({ 'id' => { '$t' => group_id } }, nil, contacts_api_user.api).contacts
  end

  def contacts_api_user
    return false if token_expired? && !refresh_token!

    unless @contact_api_user
      client = OAuth2::Client.new(APP_CONFIG['google_key'], APP_CONFIG['google_secret'])
      oath_token = OAuth2::AccessToken.new(client, token)
      @contact_api_user = GoogleContactsApi::User.new(oath_token)
    end
    @contact_api_user
  end

  def client
    return false if token_expired? && !refresh_token!

    unless @client
      @client = Google::APIClient.new(application_name: 'MPDX', application_version: '1.0')
      @client.authorization.access_token = token
    end
    @client
  end

  def refresh_token!
    if refresh_token.blank?
      needs_refresh
      return false
    end

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
          needs_refresh
          return false
        else
          fail response.inspect
        end
      end
    }
  end

  def needs_refresh
    google_integrations.each do |integration|
      integration.update_columns(calendar_integration: false, email_integration: false) #no callbacks
      AccountMailer.google_account_refresh(person, integration).deliver
    end
  end

  class MissingRefreshToken < StandardError
  end
end
