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
    account_list = import.account_list

    FbGraph::User.new(remote_id, access_token: token).friends.each do |f|
      # Add to friend set
      begin
        begin
          sleep 1 unless Rails.env.test? # facebook apparently limits api calls to 600 calls every 600s
          friend = f.fetch
        rescue OpenSSL::SSL::SSLError, HTTPClient::ConnectTimeoutError, HTTPClient::ReceiveTimeoutError
          puts "retrying on line #{__LINE__}"
          sleep 5
          retry
        rescue FbGraph::Unauthorized
          puts "retrying on line #{__LINE__}"
          sleep 60
          retry
        end

        friends << friend.identifier

        # Try to match an existing person
        fb_person = create_or_update_person(friend, account_list)

        contact = account_list.contacts.with_person(fb_person).first

        # Look for a spouse
        if friend.relationship_status == 'Married' && friend.significant_other.present?
          # skip this person if they're my spouse
          next if friend.significant_other.identifier == remote_id.to_s

          spouse = friend.significant_other.fetch(access_token: token)
          sleep 1 unless Rails.env.test?

          fb_spouse = create_or_update_person(spouse, account_list)

          # if we don't already have a contact, maybe the spouse is one
          contact ||= account_list.contacts.with_person(fb_spouse).first

          fb_person.add_spouse(fb_spouse)
        end

        unless contact
          # Create a contact
          name = "#{fb_person.last_name}, #{fb_person.first_name}"
          name += " & #{fb_spouse.first_name}" if fb_spouse

          contact = account_list.contacts.find_or_create_by_name(name)
        end

        contact.tag_list.add(import.tags, parse: true) if import.tags.present?
        contact.save

        contact.people.reload
        if fb_spouse
          contact.people << fb_spouse unless contact.person_ids.include?(fb_spouse.id)
        end
        contact.people << fb_person unless contact.person_ids.include?(fb_person.id)

      rescue => e
        Airbrake.raise_or_notify(e)
        next
      end

    end
  ensure
    update_column(:downloading, false)
  end

  def create_or_update_person(friend, account_list)
    birthday = friend.raw_attributes['birthday'].to_s.split('/')

    person_attributes = {
      first_name: friend.first_name,
      last_name: friend.last_name,
      middle_name: friend.middle_name,
      gender: friend.gender,
      birthday_month: birthday[0],
      birthday_day: birthday[1],
      birthday_year: birthday[2],
      marital_status: friend.relationship_status
    }.select { |_, v| v.present? }


    # First from my contacts
    fb_person = account_list.people.includes(:facebook_account).where('person_facebook_accounts.remote_id' => friend.identifier).first

    # If we can't find a contact with this fb account, see if we have a contact with the same name and no fb account
    unless fb_person
      fb_person = account_list.people.includes(:facebook_account).where('person_facebook_accounts.remote_id' => nil, 
                                                                        'people.first_name' => friend.first_name,
                                                                        'people.last_name' => friend.last_name).first

    end

    if fb_person
      fb_person.update_attributes(person_attributes)
    else
      # Look for a matching person auth an authenticated fb account
      account = Person::FacebookAccount.where(remote_id: friend.identifier, authenticated: true).first
      if account
        # Create a new person using the same master_person
        fb_person = account.person.master_person.people.create(person_attributes)
      else
        begin
          fb_person = Person.create!(person_attributes)
        rescue ActiveRecord::RecordInvalid => e
          raise person_attributes.inspect
        end
      end

    end

    unless fb_person.facebook_accounts.pluck(:remote_id).include?(friend.identifier.to_i)
      # Create a facebook account
      fb_person.facebook_accounts.create!(remote_id: friend.identifier,
                                          authenticated: true,
                                          first_name: friend.first_name,
                                          last_name: friend.last_name)
    end

    # add phone number and email if available
    fb_person.email = friend.email if friend.email.present?
    fb_person.phone_number = {number: friend.mobile_phone, location: 'mobile'} if friend.mobile_phone.present?
    fb_person.save

    fb_person
  end

  def self.search(user, params)
    if account = user.facebook_accounts.first
      FbGraph::User.search(params.slice(:first_name, :last_name).values.join(' '), access_token: account.token)
    else
      []
    end
  end



end
