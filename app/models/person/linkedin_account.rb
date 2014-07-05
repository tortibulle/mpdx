class Person::LinkedinAccount < ActiveRecord::Base
  include Person::Account

  scope :valid_token, -> { where('(token_expires_at is null OR token_expires_at > ?) AND valid_token = ?', Time.now, true) }

  # attr_accessible :first_name, :last_name, :url

  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.linkedin_accounts
    @remote_id = auth_hash['uid']
    params = auth_hash.extra.access_token.params
    expires_in = params[:oauth_expires_in].to_i > params[:oauth_authorization_expires_in].to_i ? params[:oauth_authorization_expires_in].to_i : params[:oauth_expires_in].to_i
    @attributes = {
                    remote_id: @remote_id,
                    token: auth_hash.credentials.token,
                    secret: auth_hash.credentials.secret,
                    token_expires_at: expires_in > 0 ? expires_in.seconds.from_now : nil,
                    first_name: auth_hash.info.first_name,
                    last_name: auth_hash.info.last_name,
                    valid_token: true
                  }
    super
  end

  def to_s
    [first_name, last_name].join(' ')
  end

  def url
    public_url
  end

  def url=(value)
    return value if value == public_url

    # grab some valid linkedin credentials
    l = Person::LinkedinAccount.valid_token.first
    raise LinkedIn::Errors::UnauthorizedError, _('The connection to your LinkedIn account needs to be renewed.') unless l

    begin
      LINKEDIN.authorize_from_access(l.token, l.secret)

      value = 'http://' + value unless value.include?('http')

      json = LINKEDIN.profile(url: value, fields: %w[id first_name last_name public-profile-url])
      update_attributes_from_json(json)
    rescue RestClient::ResourceNotFound
      destroy
    rescue LinkedIn::Errors::UnauthorizedError
      # Apparently this account wasn't valid after all
      l.update_column(:valid_token, false)
      self.url = value
    end
  end

  def update_attributes_from_json(json)
    self.remote_id = json['id']
    self.first_name = json['first_name']
    self.last_name = json['last_name']
    self.public_url = json['public_profile_url']
  end

  def queue_import_data
  end
end
