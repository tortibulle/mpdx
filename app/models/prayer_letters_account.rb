require 'async'

class PrayerLettersAccount < ActiveRecord::Base

  include Async
  include Sidekiq::Worker
  sidekiq_options queue: :general, unique: true
  SERVICE_URL = 'https://www.prayerletters.com'

  belongs_to :account_list

  validates :token, :secret, :account_list_id, presence: true

  def queue_subscribe_contacts
    async(:subscribe_contacts)
  end

  def subscribe_contacts
    contacts = []

    account_list.contacts.includes([:primary_address, {primary_person: :companies}]).each do |contact|
      if contact.send_physical_letter? &&
         contact.addresses.present? &&
         contact.active? &&
         contact.mailing_address.valid_mailing_address?

        params = {
          name: contact.envelope_greeting,
          greeting: contact.greeting,
          file_as: contact.name,
          contact_id: contact.prayer_letters_id,
          address: {
            street: contact.mailing_address.street,
            city: contact.mailing_address.city,
            state: contact.mailing_address.state,
            postal_code: contact.mailing_address.postal_code,
            country: contact.mailing_address.country
          },
          external_id: contact.id
        }
        if contact.primary_person
          name = contact.primary_person.companies.first.try(:name)
          params[:company] = name if name
        end
        contacts << params
      end
    end

    get_response(:put, '/api/v1/contacts', {contacts: contacts}.to_json)

    # Now that we've replaced the list, we need to fetch the whole list and match it to our existing contacts

    import_list
  end

  def import_list
    contacts = JSON.parse(get_response(:get, '/api/v1/contacts'))['contacts']

    contacts.each do |pl_contact|
      if pl_contact['external_id'] && contact = account_list.contacts.where(id: pl_contact['external_id']).first
        contact.update_column(:prayer_letters_id, pl_contact['contact_id'])
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
    async(:async_add_or_update_contact, contact.id)
  end

  def async_add_or_update_contact(contact_id)
    contact = account_list.contacts.find(contact_id)
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


