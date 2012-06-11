class Person::GoogleAccount < ActiveRecord::Base
  extend Person::Account

  attr_accessible :email

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

end
