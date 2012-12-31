require 'async'
require 'retryable'
class Person::FacebookAccount < ActiveRecord::Base
  include Redis::Objects
  include Async
  extend Person::Account

  def self.queue() :facebook; end

  set :friends
  # attr_accessible :remote_id, :token, :token_expires_at, :first_name, :last_name, :valid_token, :authenticated, :url

  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.facebook_accounts
    @remote_id = auth_hash['uid']
    @attributes = {
      remote_id: @remote_id,
      token: auth_hash.credentials.token,
      token_expires_at: Time.at(auth_hash.credentials.expires_at),
      first_name: auth_hash.info.first_name,
      last_name: auth_hash.info.last_name,
      valid_token: true
    }
    super
  end

  def self.create_user_from_auth(auth_hash)
    @attributes = {
      first_name: auth_hash.info.first_name,
      last_name: auth_hash.info.last_name
    }

    super
  end

  def to_s
    [first_name, last_name].join(' ')
  end

  def url
    "http://facebook.com/profile.php?id=#{remote_id}" if remote_id.to_i > 0
  end

  def url=(value)
    self.remote_id = get_id_from_url(value)
    unless remote_id.present?
      raise Errors::FacebookLink, _('We were unable to link this person to the facebook url you provided. Check the url you entered and try again. If you are currently running the "Import contacts from facebook" process, please wait until you get the email saying the import finished before trying again.')
    end
  end

  def get_id_from_url(url)
    Person::FacebookAccount.get_id_from_url(url)
  end

  def self.get_id_from_url(url)
    return nil unless url.present?

    begin
      Retryable.retryable :on => [RestClient::Forbidden, Timeout::Error, Errno::ECONNRESET], :times => 6, :sleep => 0.5 do
        # e.g. https://graph.facebook.com/nmfdelacruz)
        if url.include?("id=")
          id = url.split('id=').last
          id = id.split('&').first
        else
          name = url.split('/').last
          name = name.split('?').first
          response = RestClient.get("https://graph.facebook.com/#{name}", { accept: :json})
          json = JSON.parse(response)
          raise RestClient::ResourceNotFound unless json['id'].to_i > 0
          json['id']
        end.to_i
      end
    rescue RestClient::ResourceNotFound
    rescue RestClient::BadRequest
      raise Errors::FacebookLink, _('We were unable to link this person to the facebook url you provided. This is likely due to facebook privacy settings this person has set. If they are your friend on facebook, try using the "Import contacts from facebook" feature instead of manually pasting the link in.')
    end
  end

  def queue_import_contacts(import)
    async(:import_contacts, import.id)
  end

  def token_missing_or_expired?(tries = 0)
    # If we have an expired token, try once to refresh it
    if tries == 0 && token && (!token_expires_at || token_expires_at > Time.now)
      begin
        refresh_token
      rescue; end
      token_missing_or_expired?(1)
    else
      token.blank? || !token_expires_at || token_expires_at < Time.now
    end
  end

  def refresh_token
    info = Koala::Facebook::OAuth.new(APP_CONFIG['facebook_key'], APP_CONFIG['facebook_secret']).exchange_access_token_info(token)
    self.token = info['access_token']
    self.token_expires_at = Time.at(info['expires'])
    save
  end

  # Refresh any tokens that will be expiring soon
  def refresh_tokens
    Person::FacebookAccount.where("token_expires_at < ? AND token_expires_at > ?", 2.days.from_now, Time.now).each do |fa|
      fa.refresh_token
    end
  end

  private

  def import_contacts(import_id)
    import = Import.find(import_id)
    FacebookImport.new(self, import).import_contacts
  ensure
    update_column(:downloading, false)
  end

  def self.search(user, params)
    if account = user.facebook_accounts.first
      FbGraph::User.search(params.slice(:first_name, :last_name).values.join(' '), access_token: account.token)
    else
      []
    end
  end



end
