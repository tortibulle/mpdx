require 'async'
require 'open-uri'

class PrayerLettersAccount < ActiveRecord::Base
  include Async
  include Sidekiq::Worker
  sidekiq_options unique: true
  SERVICE_URL = 'https://www.prayerletters.com'

  belongs_to :account_list

  after_create :queue_subscribe_contacts

  validates :oauth2_token, :account_list_id,  presence: true

  def queue_subscribe_contacts
    async(:subscribe_contacts)
  end

  def subscribe_contacts
    contacts = []

    account_list.contacts.includes([:primary_address, { primary_person: :companies }]).each do |contact|
      next unless contact.send_physical_letter? &&
                  contact.mailing_address.present? &&
                  contact.active? &&
                  contact.mailing_address.valid_mailing_address? &&
                  contact.primary_person.present? &&
                  contact.envelope_greeting.present? &&
                  contact.name.present?
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
    contact_params = contact_params(contact)
    json = JSON.parse(get_response(:post, '/api/v1/contacts', contact_params))
    contact.update_column(:prayer_letters_id, json['contact_id'])
  rescue AccessError
    # do nothing
  rescue RestClient::BadRequest => e
    # BadRequest: A contact must have a name or company. Monitor those cases for pattern / underlying causes.
    Airbrake.raise_or_notify(e, parameters: contact_params)
  end

  def update_contact(contact)
    get_response(:post, "/api/v1/contacts/#{contact.prayer_letters_id}", contact_params(contact))
  rescue AccessError
    # do nothing
  rescue RestClient::Gone
    handle_missing_contact(contact)
  rescue RestClient::ResourceNotFound
    handle_missing_contact(contact)
  end

  def handle_missing_contact(contact)
    contact.update_column(:prayer_letters_id, nil)
    subscribe_contacts
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
    return unless active?

    RestClient::Request.execute(method: method, url: SERVICE_URL + path, payload: params, timeout: 120,
                                headers: { 'Authorization' => "Bearer #{ URI.encode(oauth2_token) }" })
  rescue RestClient::Unauthorized
    handle_bad_token
  end

  def handle_bad_token
    update_column(:valid_token, false)
    AccountMailer.prayer_letters_invalid_token(account_list).deliver

    fail AccessError
  end

  class AccessError < StandardError
  end
end
