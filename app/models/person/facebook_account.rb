require 'async'
class Person::FacebookAccount < ActiveRecord::Base
  include Redis::Objects
  include Async
  extend Person::Account

  def self.queue() :facebook; end

  set :friends
  attr_accessible :remote_id, :token, :token_expires_at, :first_name, :last_name, :valid_token, :authenticated, :url

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
    begin
      self.remote_id = get_id_from_url(value)
    rescue RestClient::ResourceNotFound
      self.destroy
    end
  end

  def get_id_from_url(url)
    # e.g. https://graph.facebook.com/nmfdelacruz)
    if url.include?("id=")
      url.split('id=').last
    else
      name = url.split('/').last
      response = RestClient.get("https://graph.facebook.com/#{name}", { accept: :json})
      json = JSON.parse(response)
      raise RestClient::ResourceNotFound unless json['id'].to_i > 0
      json['id']
    end.to_i
  end

  def queue_import_contacts(import)
    async(:import_contacts, import.id)
  end

  def token_missing_or_expired?
    token.blank? || !token_expires_at || token_expires_at < Time.now
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
