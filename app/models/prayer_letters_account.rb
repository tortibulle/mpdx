require 'async'
require 'open-uri'

class PrayerLettersAccount < ActiveRecord::Base
  include Async
  include Sidekiq::Worker
  sidekiq_options unique: true
  SERVICE_URL = 'https://www.prayerletters.com'

  belongs_to :account_list

  after_create :queue_subscribe_contacts

  validates :oauth1_or_2_tokens, :account_list_id,  presence: true

  def oauth1_or_2_tokens
    oauth2_token.present? || (token.present? & secret.present?)
  end

  def queue_subscribe_contacts
    async(:subscribe_contacts)
  end

  def subscribe_contacts
    contacts = []

    account_list.contacts.includes([:primary_address, { primary_person: :companies }]).each do |contact|
      next unless contact.send_physical_letter? &&
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
      if contact.siebel_organization?
        params[:name] = nil
        params[:company] = contact.name
      end
      contacts << params
    end

    get_response(:put, '/api/v1/contacts', { contacts: contacts }.to_json)

    # Now that we've replaced the list, we need to fetch the whole list and match it to our existing contacts

    import_list
  end

  def import_list
    contacts = JSON.parse(get_response(:get, '/api/v1/contacts'))['contacts']

    contacts.each do |pl_contact|
      next unless pl_contact['external_id'] && contact = account_list.contacts.where(id: pl_contact['external_id']).first
      contact.update_column(:prayer_letters_id, pl_contact['contact_id'])
    end
  end

  def active?
    valid_token?
  end

  def contacts(params = {})
    JSON.parse(get_response(:get, '/api/v1/contacts?' + params.map { |k, v| "#{k}=#{v}" }.join('&')))['contacts']
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
    json = JSON.parse(get_response(:post, '/api/v1/contacts', contact_params(contact)))
    contact.update_column(:prayer_letters_id, json['contact_id'])
  rescue AccessError
    # do nothing
  rescue => error_from_request
    begin
      json = JSON.parse(error_from_request.message)
      case json['status']
      when 400
        # A contact must have a name or company.
      else
        fail error_from_request.message
      end
    rescue => err_message_parse_err
      # This code will help us better identify the root cause of certain errors that were causing JSON parse errors
      # for the line above json = JSON.parse(error_from_request.message)
      Airbrake.raise_or_notify(error_from_request)
      Airbrake.raise_or_notify(err_message_parse_err)
      raise error_from_request
    end
  end

  def update_contact(contact)
    get_response(:post, "/api/v1/contacts/#{contact.prayer_letters_id}", contact_params(contact))
  rescue AccessError
    # do nothing
  rescue => e
    json = JSON.parse(e.message)
    case json['status']
    when 410, 404
      contact.update_column(:prayer_letters_id, nil)
      create_contact(contact)
    else
      raise e.message
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
    if contact.siebel_organization?
      params[:name] = nil
      params[:company] = contact.name
    end
    params
  end

  def get_response(method, path, params = nil)
    # Use OAuth2 if token present
    return oauth2_request(method, path, params) if oauth2_token.present?

    # Otherwise queue an overall upgrade of prayer letters accounts to OAuth2, but use OAuth1 for this request
    PrayerLettersOAuthUpgrader.perform_async
    oauth1_request(method, path, params)
  end

  def oauth2_request(method, path, params = nil)
    RestClient::Request.execute(method: method, url: SERVICE_URL + path, payload: params.to_json,
                                headers: { 'Authorization' => "Bearer #{ URI.encode(oauth2_token) }" })
  rescue RestClient::Unauthorized
    handle_bad_token
  rescue => e
    Airbrake.raise_or_notify(e, parameters:  { method: method, path: path, params: params })
  end

  def oauth1_request(method, path, params = nil)
    consumer = OAuth::Consumer.new(APP_CONFIG['prayer_letters_key'], APP_CONFIG['prayer_letters_secret'],  site: SERVICE_URL, scheme: :query_string, oauth_version: '1.0')
    oauth_token = OAuth::Token.new(token, secret)
    response = consumer.request(method, path, oauth_token, {}, params)
    case response.code.to_i
    when 200, 201, 202, 204
      response.body
    when 401
      handle_bad_token
    else
      fail response.body
    end
  rescue => e
    Airbrake.raise_or_notify(e, parameters:  { method: method, path: path, params: params })
  end

  def upgrade_to_oauth2
    return if oauth2_token.present?
    json = JSON.parse(oauth1_request(:get, '/api/oauth1/v2migration'))
    update(oauth2_token: json['access_token'])
  rescue => e
    Airbrake.raise_or_notify(e)
  end

  def handle_bad_token
    update_column(:valid_token, false)
    AccountMailer.prayer_letters_invalid_token(account_list).deliver

    fail AccessError
  end

  class AccessError < StandardError
  end
end
