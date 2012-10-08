require 'async'

class MailChimpAccount < ActiveRecord::Base
  include Async

  List = Struct.new(:id, :name)

  belongs_to :account_list

  attr_accessible :api_key, :primary_list_id

  validates :account_list_id, :api_key, presence: true

  before_create :set_active
  after_save :queue_import_if_list_chagned

  def self.queue() :general; end

  def lists
    return [] unless api_key.present?
    @list_response ||= gb.lists
    return [] unless @list_response['data']
    @lists ||= @list_response['data'].collect { |l| List.new(l['id'], l['name']) }
  end

  def list(list_id)
    lists.detect { |l| l.id == list_id }
  end

  def primary_list
    list(primary_list_id) if primary_list_id.present?
  end

  def validate_key
    @list_response ||= gb.lists
    if @list_response['code'] == 104 # Invalid API key
      self.active = false
      return @list_response['error']
    else
      self.active = true
    end
    save
    true
  end

  def datacenter
    api_key.to_s.split('-').last
  end

  def queue_export_to_primary_list
    async(:subscribe_contacts)
  end


  def queue_subscribe_contact(contact)
    async(:subscribe_contacts, contact.id)
  end

  def queue_unsubscribe_contact(contact)
    async(:unsubscribe_contact, contact.id)
  end

  private

  def unsubscribe_email(email)
    logger.debug(email)
    if email.present?
      gb.list_unsubscribe(id: primary_list_id, email_address: email,
                            send_goodbye: false, delete_member: true)
    end
  end

  def unsubscribe_contact(contact_id)
    contact = Contact.includes(people: :primary_email_address).where(id: contact_id).first

    contact.people.each do |person|
      unsubscribe_email(person.primary_email_address.try(:email))
    end
  end

  def subscribe_contacts(contact_ids = nil)
    if contact_ids
      contacts = Contact.where(id: contact_ids)
    else
      contacts = account_list.contacts
    end
    contacts = contacts.
               includes(people: :primary_email_address).
               where(send_newsletter: ['Email', 'Both']).
               where('email_addresses.email is not null')

    export_to_list(primary_list_id, contacts)
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
                     :LNAME => person.last_name, :GROUPINGS => [{id: grouping_id,
                                                                groups: _(contact.status)}] }
        end
      end
    end

    gb.list_batch_subscribe(id: list_id, batch: batch, update_existing: true, double_optin: false,
                            send_welcome: false, replace_interests: true)

    # Batch subscribe times out, so for now we'll add the people using a loop.
    #responses = []
    #batch.each do |person|
      #responses << gb.list_subscribe(id: list_id, email_address: person[:EMAIL], update_existing: true,
                        #double_optin: false, merge_vars: person, send_welcome: false, replace_interests: true)
    #end
    #responses
  end

  def add_status_groups(list_id, statuses)
    statuses = statuses.select(&:present?)

    if statuses.present?
      groupings = gb.list_interest_groupings(id: list_id)

      if groupings[0] && ((grouping = groupings.detect { |g| g['id'] == grouping_id }) ||
                          (grouping = groupings.detect { |g| g['name'] == _('Partner Status') }))

        self.grouping_id = grouping['id']

        # make sure the grouping is hidden
        gb.list_interest_grouping_add(grouping_id: grouping_id, name: 'type', value: 'hidden')

        # Add any new groups
        groups = grouping['groups'].collect { |g| g['name'] }

        (statuses - groups).each do |group|
          gb.list_interest_group_add(id: list_id, group_name: group, grouping_id: grouping_id)
        end

      else
        # create a new grouping
        self.grouping_id = gb.list_interest_grouping_add(id: list_id, name: _('Partner Status'), type: 'hidden', 
                                                         groups: statuses.map { |s| _(s) })
      end
      save

    end
  end

  def queue_import_if_list_chagned
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


