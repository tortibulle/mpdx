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
    async(:export_to_primary_list)
  end

  private

  def export_to_primary_list

    contacts = account_list.contacts.includes(people: :primary_email_address).where(send_newsletter: ['Email', 'Both'])
    # Make sure we have an interest group for each status of partner set
    # to receive the newsletter
    statuses = contacts.pluck('status').uniq

    add_status_groups(statuses)

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

    gb.list_batch_subscribe(id: primary_list_id, batch: batch, update_existing: true, double_optin: false,
                            send_welcome: false, replace_interests: true)

    # Batch subscribe times out, so for now we'll add the people using a loop.
    #responses = []
    #batch.each do |person|
      #responses << gb.list_subscribe(id: primary_list_id, email_address: person[:EMAIL], update_existing: true,
                        #double_optin: false, merge_vars: person, send_welcome: false, replace_interests: true)
    #end
    #responses
  end

  def add_status_groups(statuses)
    statuses = statuses.select(&:present?)

    if statuses.present?
      groupings = gb.list_interest_groupings(id: primary_list_id)

      if groupings[0] && (grouping = groupings.detect { |g| g['id'] == grouping_id })
        # make sure the grouping is hidden
        gb.list_interest_grouping_add(grouping_id: grouping_id, name: 'type', value: 'hidden')

        # Add any new groups, remove any no longer being used
        groups = grouping['groups'].collect { |g| g['name'] }

        (groups - statuses).each do |group|
          gb.list_interest_group_del(id: primary_list_id, group_name: group, grouping_id: grouping_id)
        end

        (statuses - groups).each do |group|
          gb.list_interest_group_add(id: primary_list_id, group_name: group, grouping_id: grouping_id)
        end

      else
        # create a new grouping
        self.grouping_id = gb.list_interest_grouping_add(id: primary_list_id, name: _('Partner Status'), type: 'hidden', 
                                                         groups: statuses.map { |s| _(s) })
        save
      end

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


