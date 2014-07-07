class Contact < ActiveRecord::Base
  include AddressMethods
  acts_as_taggable

  has_paper_trail on: [:destroy, :update],
                  meta: { related_object_type: 'AccountList',
                          related_object_id: :account_list_id }

  has_many :contact_donor_accounts, dependent: :destroy, inverse_of: :contact
  has_many :donor_accounts, through: :contact_donor_accounts, inverse_of: :contacts
  has_many :donations, through: :donor_accounts
  belongs_to :account_list
  has_many :contact_people, dependent: :destroy
  has_many :people, -> { order('contact_people.primary::int desc') }, through: :contact_people
  has_one :primary_contact_person, -> { where(primary: true) }, class_name: 'ContactPerson'
  has_one :primary_person, through: :primary_contact_person, source: :person
  has_one :spouse_contact_person, -> { where(['"primary" = ? OR "primary" is NULL', false]) }, class_name: 'ContactPerson'
  has_one :spouse, through: :spouse_contact_person, source: :person
  has_many :contact_referrals_to_me, foreign_key: :referred_to_id, class_name: 'ContactReferral', dependent: :destroy
  has_many :contact_referrals_by_me, foreign_key: :referred_by_id, class_name: 'ContactReferral', dependent: :destroy
  has_many :referrals_to_me, through: :contact_referrals_to_me, source: :referred_by
  has_many :referrals_by_me, through: :contact_referrals_by_me, source: :referred_to
  has_many :activity_contacts, dependent: :destroy
  has_many :activities, through: :activity_contacts
  has_many :tasks, through: :activity_contacts, source: :task
  has_many :notifications, inverse_of: :contact, dependent: :destroy
  has_many :messages

  scope :people, -> { where('donor_accounts.master_company_id is null').includes(:donor_accounts).references('donor_accounts') }
  scope :companies, -> { where('donor_accounts.master_company_id is not null').includes(:donor_accounts).references('donor_accounts') }
  scope :with_person, -> (person) { includes(:people).where('people.id' => person.id) }
  scope :for_donor_account, -> (donor_account) { where('donor_accounts.id' => donor_account.id).includes(:donor_accounts).references('donor_accounts') }
  scope :financial_partners, -> { where(status: 'Partner - Financial') }
  scope :non_financial_partners, -> { where("status <> 'Partner - Financial' OR status is NULL") }

  scope :with_referrals, -> { joins(:contact_referrals_by_me).uniq }
  scope :active, -> { where(active_conditions) }
  scope :inactive, -> { where(inactive_conditions) }
  scope :late_by, -> (min_days, max_days = nil) { financial_partners.where('last_donation_date BETWEEN ? AND ?', max_days ? Date.today - max_days : Date.new(1951, 1, 1), Date.today - min_days) }

  PERMITTED_ATTRIBUTES = [
    :name, :pledge_amount, :status, :notes, :full_name, :greeting, :website, :pledge_frequency,
    :pledge_start_date, :next_ask, :never_ask, :likely_to_give, :church_name, :send_newsletter,
    :direct_deposit, :magazine, :pledge_received, :not_duplicated_with, :tag_list, :primary_person_id, :timezone,
    {
      contact_referrals_to_me_attributes: [:referred_by_id, :_destroy, :id],
      donor_accounts_attributes: [:account_number, :organization_id, :_destroy, :id],
      addresses_attributes: [:remote_id, :master_address_id, :location, :street, :city, :state, :postal_code, :region, :metro_area, :country, :primary_mailing_address, :_destroy, :id],
      people_attributes: Person::PERMITTED_ATTRIBUTES
    }
  ]

  validates :name, presence: true

  accepts_nested_attributes_for :people, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :donor_accounts, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :contact_people, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :contact_referrals_to_me, reject_if: :all_blank, allow_destroy: true

  before_save :set_notes_saved_at
  after_commit :sync_with_mail_chimp, :sync_with_prayer_letters, :set_timezone
  before_destroy :delete_from_prayer_letters, :delete_people

  assignable_values_for :status, allow_blank: true do
    # Don't change these willy-nilly, they break the mobile app
    [_('Never Contacted'), _('Ask in Future'), _('Contact for Appointment'), _('Appointment Scheduled'),
     _('Call for Decision'), _('Partner - Financial'), _('Partner - Special'), _('Partner - Pray'),
     _('Not Interested'), _('Unresponsive'), _('Never Ask'),
     _('Research Abandoned'), _('Expired Referral')]
  end

  IN_PROGRESS_STATUSES = [_('Never Contacted'), _('Ask in Future'), _('Contact for Appointment'), _('Appointment Scheduled'), _('Call for Decision')]

  TABS = {
    'details' => _('Details'),
    'tasks' => _('Tasks'),
    'history' => _('History'),
    'referrals' => _('Referrals'),
    'notes' => _('Notes'),
    'social' => _('Social')
  }

  def status=(val)
    # handle deprecated values
    case val
    when 'Call for Appointment'
      self[:status] = 'Contact for Appointment'
    else
      self[:status] = val
    end
  end

  assignable_values_for :likely_to_give, allow_blank: true do
    [_('Least Likely'), _('Likely'), _('Most Likely')]
  end

  assignable_values_for :send_newsletter, allow_blank: true do
    [_('Physical'), _('Email'), _('Both')]
  end

  delegate :first_name, :last_name, :phone, :email, to: :primary_or_first_person
  delegate :street, :city, :state, :postal_code, to: :mailing_address

  def to_s() name; end

  def add_person(person)
    # Nothing to do if this person is already on the contact
    new_person = people.where(master_person_id: person.master_person_id).first

    unless new_person
      new_person = Person.clone(person)
      people << new_person
    end

    new_person
  end

  def mailing_address
    @mailing_address ||= primary_address || addresses.first || Address.new
  end

  def hide
    update_attributes(status: 'Never Ask')
  end

  def active?
    !Contact.inactive_statuses.include?(status)
  end

  def self.active_conditions
    "status NOT IN('#{inactive_statuses.join("','")}') or status is null"
  end

  def self.inactive_conditions
    "status IN('#{inactive_statuses.join("','")}')"
  end

  def self.inactive_statuses
    ['Not Interested', 'Unresponsive', 'Never Ask', 'Research Abandoned', 'Expired Referral']
  end

  def self.create_from_donor_account(donor_account, account_list)
    contact = account_list.contacts.new(name: donor_account.name)
    contact.addresses_attributes = Hash[donor_account.addresses.collect.with_index { |address, i| [i, address.attributes.slice(*%w(street city state country postal_code))] }]
    contact.save!
    contact.donor_accounts << donor_account
    contact
  end

  def primary_or_first_person
    unless @primary_or_first_person
      @primary_or_first_person = primary_person
      if !@primary_or_first_person && people.present?
        @primary_or_first_person = people.where(gender: 'male').first || people.order('created_at').first
        if @primary_or_first_person && @primary_or_first_person.new_record? && !self.new_record?
          self.primary_person_id = @primary_or_first_person.id
        end
      end
    end
    @primary_or_first_person || Person.new
  end

  def primary_person_id
    primary_or_first_person.id
  end

  def primary_person_id=(person_id)
    if person_id
      cp = contact_people.where(person_id: person_id).first
      cp.update_attributes(primary: true) if cp
    end
    person_id
  end

  def spouse_name
    spouse.try(:first_name)
  end

  def spouse_phone
    spouse.try(:spouse_phone)
  end

  def spouse_email
    spouse.try(:spouse_email)
  end

  def greeting
    return name if siebel_organization?
    self[:greeting] || [first_name, spouse_name].compact.join(_(' and '))
  end

  def envelope_greeting
    return name if siebel_organization?
    greeting.include?(last_name.to_s) ? greeting : [greeting, last_name].compact.join(' ')
  end

  def siebel_organization?
    last_name == 'of the Ministry'
  end

  def update_donation_totals(donation)
    self.first_donation_date = donation.donation_date if first_donation_date.nil? || donation.donation_date < first_donation_date
    self.last_donation_date = donation.donation_date if last_donation_date.nil? || donation.donation_date > last_donation_date
    self.total_donations = total_donations.to_f + donation.amount
    save(validate: false)
  end

  def monthly_pledge
    pledge_amount.to_f / (pledge_frequency || 1)
  end

  def send_email_letter?
    %w(Email Both).include?(send_newsletter)
  end

  def send_physical_letter?
    %w(Physical Both).include?(send_newsletter)
  end

  def not_same_as?(other)
    not_duplicated_with.to_s.split(',').include?(other.id.to_s)
  end

  def donor_accounts_attributes=(attribute_collection)
    attribute_collection = attribute_collection.with_indifferent_access.values
    attribute_collection.each do |attrs|
      case
      when attrs[:id].present? && (attrs[:account_number].blank? || attrs[:_destroy] == '1')
        ContactDonorAccount.where(donor_account_id: attrs[:id], contact_id: id).destroy_all
      when attrs[:account_number].blank?
        next
      when donor_account = DonorAccount.where(account_number: attrs[:account_number], organization_id: attrs[:organization_id]).first
        contact_donor_accounts.new(donor_account: donor_account) unless donor_account.contacts.include?(self)
      else
        assign_nested_attributes_for_collection_association(:donor_accounts, [attrs])
      end
    end
  end

  def merge(other)
    Contact.transaction do
      # Update related records
      other.messages.update_all(contact_id: id)

      other.contact_people.each do |r|
        unless contact_people.where(person_id: r.person_id).first
          r.update_attributes(contact_id: id)
        end
      end

      other.contact_donor_accounts.each do |other_contact_donor_account|
        unless donor_accounts.map(&:account_number).include?(other_contact_donor_account.donor_account.account_number)
          other_contact_donor_account.update_column(:contact_id, id)
        end
      end

      other.activity_contacts.each do |other_activity_contact|
        unless activities.include?(other_activity_contact.activity)
          other_activity_contact.update_column(:contact_id, id)
        end
      end
      update_uncompleted_tasks_count

      other.addresses.each do |other_address|
        unless addresses.find { |address| address.equal_to? other_address }
          other_address.update_column(:addressable_id, id)
        end
      end

      other.notifications.update_all(contact_id: id)

      merge_addresses

      ContactReferral.where(referred_to_id: other.id).each do |contact_referral|
        contact_referral.update_column(:referred_to_id, id) unless contact_referrals_to_me.find { |crtm| crtm.referred_by_id == contact_referral.referred_by_id }
      end

      ContactReferral.where(referred_by_id: other.id).update_all(referred_by_id: id)

      # Copy fields over updating any field that's blank on the winner
      [:name, :pledge_amount, :status, :greeting, :website,
       :pledge_frequency, :pledge_start_date, :next_ask, :never_ask, :likely_to_give,
       :church_name, :send_newsletter, :direct_deposit, :magazine, :last_activity, :last_appointment,
       :last_letter, :last_phone_call, :last_pre_call, :last_thank, :prayer_letters_id].each do |field|
         if send(field).blank? && other.send(field).present?
           send("#{field}=".to_sym, other.send(field))
         end
       end

       # If one of these is marked as a finanical partner, we want that status
      if status != 'Partner - Financial' && other.status == 'Partner - Financial'
        self.status = 'Partner - Financial'
      end

      self.notes = [notes, other.notes].compact.join("\n").strip if other.notes.present?

      self.tag_list += other.tag_list

      save(validate: false)
    end

    # Delete the losing record
    begin
      other.reload
      other.destroy
    rescue ActiveRecord::RecordNotFound; end

    reload
    merge_people
    merge_donor_accounts
  end

  def deceased
    people.all?(&:deceased)
  end

  def deceased?
    deceased
  end

  def self.pledge_frequencies
    {
      (0.23076923076923).to_d => _('Weekly'),
      (0.46153846153846).to_d => _('Fortnightly'),
      (1.0).to_d => _('Monthly'),
      (2.0).to_d => _('Bi-Monthly'),
      (3.0).to_d => _('Quarterly'),
      (4.0).to_d => _('Quad-Monthly'),
      (6.0).to_d => _('Semi-Annual'),
      (12.0).to_d => _('Annual'),
      (24.0).to_d => _('Biennial')
    }
  end

  def merge_addresses
    ordered_addresses = addresses.order('created_at desc')
    ordered_addresses.reload
    ordered_addresses.each do |address|
      other_address = ordered_addresses.find { |a| a.id != address.id && a.equal_to?(address) }
      if other_address
        address.merge(other_address)
        merge_addresses
        return
      end
    end
  end

  def merge_people
    # Merge people that have the same name
    merged_people = []

    people.reload.each do |person|
      next if merged_people.include?(person)

      if other_people = people.select { |p| p.first_name == person.first_name &&
                                              p.last_name == person.last_name &&
                                              p.id != person.id }
        other_people.each do |other_person|
          person.merge(other_person)
          merged_people << other_person
        end
      end
    end
    people.reload
    people.map(&:merge_phone_numbers)
  end

  def merge_donor_accounts
    # Merge donor accounts that have the same number
    donor_accounts.reload.each do |account|
      if other = donor_accounts.find { |da| da.id != account.id &&
                                              da.account_number == account.account_number}
        account.merge(other)
        merge_donor_accounts
        return
      end
    end
  end

  def update_uncompleted_tasks_count
    self.uncompleted_tasks_count = tasks.uncompleted.count
    save(validate: false)
  end

  def get_timezone
    primary_address = addresses.find(&:primary_mailing_address?) || addresses.first

    return unless primary_address

    begin
      latitude, longitude = Geocoder.coordinates([primary_address.street, primary_address.city, primary_address.state, primary_address.country].join(','))
      timezone = GoogleTimezone.fetch(latitude, longitude).time_zone_id
      ActiveSupport::TimeZone::MAPPING.invert[timezone]
    rescue
    end
  end

  private

  def delete_people
    people.each do |person|
      # If this person isn't linked to any other contact, delete them
      unless account_list.people.where("people.id = #{person.id} AND contact_people.contact_id <> #{id}").first
        person.destroy
      end
    end

    contact_people.destroy_all
  end

  def set_notes_saved_at
    self.notes_saved_at = DateTime.now if changed.include?('notes')
  end

  def sync_with_mail_chimp
    if mail_chimp_account = account_list.mail_chimp_account
      if changed.include?('send_newsletter')
        if send_email_letter?
          mail_chimp_account.queue_subscribe_contact(self)
        else
          mail_chimp_account.queue_unsubscribe_contact(self)
        end
      end
    end
  end

  def sync_with_prayer_letters
    if account_list.valid_prayer_letters_account
      pl = account_list.prayer_letters_account
      if send_physical_letter?
        pl.add_or_update_contact(self)
      else
        delete_from_prayer_letters
      end
    end
  end

  def delete_from_prayer_letters
    # If this contact was at prayerletters.com and no other contact on this list has the
    # same prayer_letters_id, remove this contact from prayerletters.com
    if prayer_letters_id.present? &&
       account_list.valid_prayer_letters_account &&
       !account_list.contacts.where("prayer_letters_id = '#{prayer_letters_id}' AND id <> #{id}").present?
      account_list.prayer_letters_account.delete_contact(self)
    end
  end

  def set_timezone
    update_column(:timezone, get_timezone)
  end
end
