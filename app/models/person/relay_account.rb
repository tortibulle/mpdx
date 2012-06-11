class Person::RelayAccount < ActiveRecord::Base
  extend Person::Account

  attr_accessible :username

  def self.find_or_create_from_auth(auth_hash, user)
    @rel = user.relay_accounts
    @remote_id = auth_hash.extra.attributes.first.ssoGuid
    @attributes = {
      remote_id: @remote_id, 
      first_name: auth_hash.extra.attributes.first.firstName,
      last_name: auth_hash.extra.attributes.first.lastName,
      username: auth_hash.extra.attributes.first.username,
      email: auth_hash.extra.attributes.first.email,
      designation: auth_hash.extra.attributes.first.designation,
      employee_id: auth_hash.extra.attributes.first.emplid
    }

    account = super
    account.find_or_create_org_account(auth_hash)
    account
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
    username
  end

  def find_or_create_org_account(auth_hash)
    org = Organization.find_by_name('Campus Crusade for Christ - USA')
    if (emplid = auth_hash.extra.attributes.first.emplid) && (designation = auth_hash.extra.attributes.first.designation)
      # we need to create an organization account if we don't already have one
      account = person.organization_accounts.where(organization_id: org.id).first_or_initialize
      account.assign_attributes({organization_id: org.id,
                                  remote_id: emplid,
                                  token: "#{APP_CONFIG['itg_auth_key']}_#{designation}_#{emplid}",
                                  authenticated: true,
                                  valid_credentials: true}, without_protection: true)
      account.save(validate: false)
    end

  end

  private
  #def find_or_create_designation_account(auth_hash)
    #if designation = auth_hash.extra.attributes.first.designation
      ## we need to create a designation account for this designation if we don't already have one
      #unless user.designation_numbers(org.id).include?(designation)
        #profile = user.designation_profiles.for_org(org.id).first ||
                  #user.designation_profiles.create!(organization: org, name: "Staff Account (#{designation})")

        #user.create_designation_account(designation_number: designation,
                                        #organization: org,
                                        #designation_profile: profile)
      #end
    #end
  #end
end
