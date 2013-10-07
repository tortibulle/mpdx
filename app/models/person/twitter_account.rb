class Person::TwitterAccount < ActiveRecord::Base
  extend Person::Account
  after_save :ensure_only_one_primary

  # attr_accessible :screen_name


  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.twitter_accounts
    params = auth_hash.extra.access_token.params
    @remote_id = params[:user_id]
    primary = person.twitter_accounts.present? ? false : true
    @attributes = {
                    remote_id: @remote_id, 
                    screen_name: params[:screen_name], 
                    token: params[:oauth_token],
                    secret: params[:oauth_token_secret],
                    valid_token: true,
                    primary: primary
                  }
    super
  end

  def to_s() screen_name; end

  def self.one_per_user?() false; end

  def screen_name=(value)
    return unless value
    if value =~ /https?:/
      handle = value.split('/').last
    else
      handle = value.gsub('@', '')
    end
    self[:remote_id] = handle
    self[:screen_name] = handle
  end

  def queue_import_data
    
  end

  private
    def ensure_only_one_primary
      primaries = self.person.twitter_accounts.where(primary: true)
      primaries[0..-2].map {|p| p.update_column(:primary, false)} if primaries.length > 1
    end

end
