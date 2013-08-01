require 'async'

class MailChimpAccount < ActiveRecord::Base
  include Async
  include Sidekiq::Worker
  sidekiq_options queue: :general

  List = Struct.new(:id, :name)

  belongs_to :account_list

  # attr_accessible :api_key, :primary_list_id
  attr :validation_error

  validates :account_list_id, :api_key, presence: true
  validates :api_key, format: /\w+-us\d/

  before_create :set_active
  after_save :queue_import_if_list_changed

  def lists
    begin
      return [] unless api_key.present?
      @list_response ||= gb.lists
      return [] unless @list_response['data']
      @lists ||= @list_response['data'].collect { |l| List.new(l['id'], l['name']) }
    rescue Gibbon::MailChimpError
      []
    end
  end

  def list(list_id)
    lists.detect { |l| l.id == list_id }
  end

  def primary_list
    list(primary_list_id) if primary_list_id.present?
  end

  def validate_key
    return false unless api_key.present?
    begin
      @list_response ||= gb.lists
      self.active = true
    rescue Gibbon::MailChimpError => e
      self.active = false
      @validation_error = e.message
    end
    update_column(:active, active) unless new_record?
    active
  end

  def active_and_valid?
    active? && validate_key
  end

  def queue_export_to_primary_list
    async(:call_mailchimp, :subscribe_contacts)
  end


  def queue_subscribe_contact(contact)
    async(:call_mailchimp, :subscribe_contacts, contact.id)
  end

  def queue_subscribe_person(person)
    async(:call_mailchimp, :subscribe_person, person.id)
  end

  def queue_unsubscribe_email(email)
    async(:call_mailchimp, :unsubscribe_email, email)
  end

  def queue_update_email(old_email, new_email)
    async(:call_mailchimp, :update_email, old_email, new_email)
  end


  def queue_unsubscribe_contact(contact)
    contact.people.each do |person|
      person.email_addresses.each do |email_address|
        async(:call_mailchimp, :unsubscribe_email, email_address.email)
      end
    end
  end

  def datacenter
    api_key.to_s.split('-').last
  end

  private

  def call_mailchimp(method, *args)
    if active? && primary_list_id
      begin
        send(method, *args)
      rescue Gibbon::MailChimpError => e
        case
        when e.message.include?('API Key Disabled')
          update_column(:active, false)
          AccountMailer.invalid_mailchimp_key(account_list).deliver
        when e.message.include?('code -91') # A backend database error has occurred. Please try again later or report this issue. (code -91)
          # raise the exception and the background queue will retry
          raise e
        else
          raise e
        end
      end
    end
  end

  def update_email(old_email, new_email)
    begin
      gb.list_update_member(id: primary_list_id, email_address: old_email, merge_vars: { EMAIL: new_email })
    rescue Gibbon::MailChimpError => e
      # The email address "xxxxx@example.com" does not belong to this list (code 215)
      # There is no record of "xxxxx@example.com" in the database (code 232)
      if e.message.include?('code 215') || e.message.include?('code 232')
        subscribe_email(new_email)
      else
        raise e unless e.message.include?('code 214') # The new email address "xxxxx@example.com" is already subscribed to this list and must be unsubscribed first. (code 214)
      end
    end
  end

  def unsubscribe_email(email)
    if email.present? && primary_list_id.present?
      begin
        gb.list_unsubscribe(id: primary_list_id, email_address: email,
                            send_goodbye: false, delete_member: true)
      rescue Gibbon::MailChimpError => e
        case
        when e.message.include?('code 232') || e.message.include?('code 215')
          # do nothing
        when e.message.include?('code 232') || e.message.include?('code 200')
          # Invalid MailChimp List ID
          update_column(:primary_list_id, nil)
        else
          raise e
        end
      end
    end
  end

  def subscribe_email(email)
    begin
      gb.list_subscribe(id: primary_list_id, email_address: email, update_existing: true,
                        double_optin: false, send_welcome: false, replace_interests: true)
    rescue Gibbon::MailChimpError => e
      raise e unless e.message.include?('code 214') # The new email address "xxxxx@example.com" is already subscribed to this list and must be unsubscribed first. (code 214)
    end

  end

  def subscribe_person(person_id)
    person = Person.find(person_id)
    if person.primary_email_address
      vars = { :EMAIL => person.primary_email_address.email, :FNAME => person.first_name,
               :LNAME => person.last_name}
      begin
        gb.list_subscribe(id: primary_list_id, email_address: vars[:EMAIL], update_existing: true,
                          double_optin: false, merge_vars: vars, send_welcome: false, replace_interests: true)
      rescue Gibbon::MailChimpError => e
        case
        when e.message.include?('code 250') # MMERGE3 must be provided - Please enter a value (code 250)
          # Notify user and nulify primary_list_id until they fix the problem
          update_column(:primary_list_id, nil)
          AccountMailer.mailchimp_required_merge_field(account_list).deliver
        when e.message.include?('code 200') # Invalid MailChimp List ID (code 200)
          # TODO: Notify user and nulify primary_list_id until they fix the problem
          update_column(:primary_list_id, nil)
        when e.message.include?('code 502') # Invalid Email Address: "Rajah Tony" <amrajah@gmail.com> (code 502)
        else
          raise e
        end
      end
    end
  end

  def subscribe_contacts(contact_ids = nil)
    contacts = account_list.contacts

    if contact_ids
      contacts = contacts.where(id: contact_ids)
    end

    contacts = contacts.
      includes(people: :primary_email_address).
      where(send_newsletter: ['Email', 'Both']).
      where('email_addresses.email is not null')

    export_to_list(primary_list_id, contacts.to_set)
  end


  def export_to_list(list_id, contacts)
    # Make sure we have an interest group for each status of partner set
    # to receive the newsletter
    statuses = contacts.collect(&:status).compact.uniq

    add_status_groups(list_id, statuses)

    batch = []

    contacts.each do |contact|

      # Make sure we don't try to add to a blank group
      contact.status = 'Partner - Pray' if contact.status.blank?

      contact.people.each do |person|
        if person.primary_email_address
          batch << { :EMAIL => person.primary_email_address.email, :FNAME => person.first_name,
                     :LNAME => person.last_name }
        end
      end

      # if we have a grouping_id, add them to that group
      if grouping_id.present?
        batch.each { |p| p[:GROUPINGS] ||= [{id: grouping_id, groups: _(contact.status)}] }
      end


    end

    begin
      gb.list_batch_subscribe(id: list_id, batch: batch, update_existing: true, double_optin: false,
                              send_welcome: false, replace_interests: true)
    rescue Gibbon::MailChimpError => e
      raise e
    end

  end

  def add_status_groups(list_id, statuses)
    statuses = (statuses.select(&:present?) + ['Partner - Pray']).uniq

    grouping = nil # define grouping variable outside of block
    begin
      grouping = find_grouping(list_id)
      if grouping
        self.grouping_id = grouping['id']
        # make sure the grouping is hidden
        gb.list_interest_grouping_update(grouping_id: grouping_id, name: 'type', value: 'hidden')
      end
    rescue Gibbon::MailChimpError => e
      raise e unless e.message.include?('code 211') # This list does not have interest groups enabled (code 211)
    end
    # create a new grouping
    unless grouping
      gb.list_interest_grouping_add(id: list_id, name: _('Partner Status'), type: 'hidden',
                                                         groups: statuses.map { |s| _(s) })
      grouping = find_grouping(list_id)
      self.grouping_id = grouping['id']
    end


    # Add any new groups
    groups = grouping['groups'].collect { |g| g['name'] }

    (statuses - groups).each do |group|
      gb.list_interest_group_add(id: list_id, group_name: group, grouping_id: grouping_id)
    end

    save

  end

  def find_grouping(list_id)
    groupings = gb.list_interest_groupings(id: list_id)
    groupings.detect { |g| g['id'] == grouping_id } ||
                           groupings.detect { |g| g['name'] == _('Partner Status') }
  end

  def queue_import_if_list_changed
    if changed.include?('primary_list_id')
      queue_export_to_primary_list
    end
  end

  def set_active
    self.active = true
  end

  def gb
    @gb ||= Gibbon.new(api_key)
    @gb.timeout = 600
    @gb
  end

end


