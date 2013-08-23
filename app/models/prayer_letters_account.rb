require 'async'

class PrayerLettersAccount < ActiveRecord::Base

  include Async
  include Sidekiq::Worker
  sidekiq_options queue: :general
  SERVICE_URL = 'https://www.prayerletters.com'

  belongs_to :account_list

  validates :token, :secret, :account_list_id, presence: true

  after_create :queue_subscribe_contacts

  def queue_subscribe_contacts
    async(:subscribe_contacts)
  end

  def subscribe_contacts
    delete_all_contacts

    account_list.contacts.includes(:addresses).each do |contact|
      if contact.send_physical_letter? && contact.addresses.present? && contact.active?
        add_or_update_contact(contact)
      #else
        #delete_contact(contact) if contact.prayer_letters_id
      end
    end
  end

  def validate_token
    return false unless token.present? && secret.present?
    begin
      contacts(limit: 1) # If this works, the tokens are valid
      self.valid_token = true
    rescue RestClient::Unauthorized
      self.valid_token = false
    end
    update_column(:valid_token, valid_token) unless new_record?
    valid_token
  end

  def active?
    valid_token?
  end

  def contacts(params = {})
    JSON.parse(get_response(:get, '/api/v1/contacts?' + params.collect {|k,v| "#{k}=#{v}"}.join('&')))['contacts']
  end

  def add_or_update_contact(contact)
    if contact.prayer_letters_id.present?
      update_contact(contact)
    else
      create_contact(contact)
    end
  end

  def create_contact(contact)
    begin
      json = JSON.parse(get_response(:post, '/api/v1/contacts', contact_params(contact)))
    rescue => e
      json = JSON.parse(e.message)
      case json['status']
      when 400
        # A contact must have a name or company.
      else
        raise e.message
      end
    end
    contact.update_column(:prayer_letters_id, json['contact_id'])
  end


  def update_contact(contact)
    begin
      get_response(:post, "/api/v1/contacts/#{contact.prayer_letters_id}", contact_params(contact))
    rescue => e
      json = JSON.parse(e.message)
      case json['status']
      when 410
        contact.update_column(:prayer_letters_id, nil)
        create_contact(contact)
      else
        raise e.message
      end
    end
  end

  def delete_contact(contact)
    get_response(:delete, "/api/v1/contacts/#{contact.prayer_letters_id}")
    contact.update_column(:prayer_letters_id, nil)
  end

  def delete_all_contacts
    get_response(:delete, '/api/v1/contacts')
    account_list.contacts.update_all(prayer_letters_id: nil)
  end

  def contact_params(contact)
    params = {
              name: contact.envelope_greeting,
              greeting: contact.greeting,
              file_as: contact.name,
              street: contact.mailing_address.street,
              city: contact.mailing_address.city,
              state: contact.mailing_address.state,
              postal_code: contact.mailing_address.postal_code,
              external_id: contact.id
             }
    params[:country] = contact.mailing_address.country unless contact.mailing_address.country == 'United States'
    if contact.primary_person
      name = contact.primary_person.companies.first.try(:name)
      params[:company] = name if name
    end
    params
  end

  def get_response(method, path, params = nil)
    consumer = OAuth::Consumer.new(APP_CONFIG['prayer_letters_key'], APP_CONFIG['prayer_letters_secret'], {site: SERVICE_URL, scheme: :query_string, oauth_version: '1.0'})
    oauth_token = OAuth::Token.new(token, secret)

    response = consumer.request(method, path, oauth_token, {}, params)
    case response.code
    when '200','201','202','204'
      response.body
    else
      raise response.body
    end

  end

end


