require_dependency 'address_methods'

class Contact < ActiveRecord::Base
  include AddressMethods
  acts_as_taggable

  has_many :contact_donor_accounts
  has_many :donor_accounts, through: :contact_donor_accounts
  belongs_to :account_list
  has_many :contact_people
  has_many :people, through: :contact_people
  has_many :contact_referrals_to_me, foreign_key: :referred_to_id, class_name: 'ContactReferral'
  has_many :contact_referrals_by_me, foreign_key: :referred_by_id, class_name: 'ContactReferral'
  has_many :referrals_to_me, through: :contact_referrals_to_me, source: :referred_by
  has_many :referrals_by_me, through: :contact_referrals_by_me, source: :referred_to
  has_many :activity_contacts
  has_many :activities, through: :activity_contacts
  has_many :tasks, through: :activity_contacts, source: :activity


  scope :people, where('donor_accounts.master_company_id is null').includes(:donor_accounts)
  scope :companies, where('donor_accounts.master_company_id is not null').includes(:donor_accounts)
  scope :with_person, lambda { |person| includes(:people).where('people.id' => person.id) }
  scope :for_donor_account, lambda { |donor_account| where('donor_accounts.id' => donor_account.id).includes(:donor_accounts) }


  validates :name, presence: true

  accepts_nested_attributes_for :people, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :contact_people, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :contact_referrals_to_me, reject_if: :all_blank, allow_destroy: true

  before_destroy :delete_people
  before_save    :set_notes_saved_at

  assignable_values_for :status, :allow_blank => true do
    ['Never Contacted', 'Ask in Future', 'Call for Appointment', 'Appointment Scheduled', 'Call for Decision',
    'Partner - Financial', 'Partner - Special', 'Partner - Pray', 'Not Interested', 'Unresponsive', 'Never Ask']
  end

  attr_accessible :name, :addresses_attributes, :pledge_amount, :status, :contact_referrals_to_me_attributes,
                  :people_attributes, :notes, :contact_people_attributes, :full_name, :greeting, :website,
                  :pledge_frequency, :pledge_start_date, :deceased, :next_ask, :never_ask, :likely_to_give,
                  :church_name, :send_newsletter, :direct_deposit, :magazine, :last_activity, :last_appointment,
                  :last_letter, :last_phone_call, :last_pre_call, :last_thank

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
    addresses.where(primary_mailing_address: true).first || addresses.first || Address.new
  end

  def self.create_from_donor_account(donor_account, account_list)
    contact = account_list.contacts.new({name: donor_account.name}, without_protection: true)
    contact.addresses_attributes = Hash[donor_account.addresses.collect.with_index { |address, i| [i, address.attributes.slice(*%w{street city state country postal_code})] }]
    contact.save!
    contact.donor_accounts << donor_account
    contact
  end

  def primary_person
    people.where('contact_people.primary' => true).first || people.first
  end

  def update_donation_totals(donation)
    self.first_donation_date = donation.donation_date if first_donation_date.nil? || donation.donation_date < first_donation_date
    self.last_donation_date = donation.donation_date if last_donation_date.nil? || donation.donation_date > last_donation_date
    self.total_donations = self.total_donations.to_f + donation.amount
    save(validate: false)
  end

  def monthly_pledge
    return 0 unless pledge_frequency.to_i > 0
    pledge_amount.to_f / pledge_frequency
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
end

