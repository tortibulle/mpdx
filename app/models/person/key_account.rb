class Person::KeyAccount < ActiveRecord::Base
  extend Person::Account

  #attr_accessible :email

  def self.find_or_create_from_auth(auth_hash, person)
    @rel = person.key_accounts
    @remote_id = auth_hash.extra.attributes.first.ssoGuid
    @attributes = {
                    remote_id: @remote_id,
                    first_name: auth_hash.extra.attributes.first.firstName,
                    last_name: auth_hash.extra.attributes.first.lastName,
                    email: auth_hash.extra.attributes.first.email
                  }
    super
  end

  def self.create_user_from_auth(auth_hash)
    @attributes = {
                    first_name: auth_hash.extra.attributes.first.firstName,
                    last_name: auth_hash.extra.attributes.first.lastName
                  }

    super
  end

  def self.find_authenticated_user(auth_hash)
    User.find_by_id(authenticated.where(remote_id: auth_hash.extra.attributes.first.ssoGuid).pluck(:person_id).first)
  end


  def to_s
    email
  end

  def queue_import_data

  end
end
