class Person < ActiveRecord::Base

  belongs_to :master_person
  has_many :email_addresses, dependent: :destroy
  has_one :primary_email_address, class_name: 'EmailAddress', foreign_key: :person_id, conditions: {'email_addresses.primary' => true}
  has_many :phone_numbers, dependent: :destroy
  has_one :primary_phone_number, class_name: 'PhoneNumber', foreign_key: :person_id, conditions: {'phone_numbers.primary' => true}
  has_many :family_relationships, dependent: :destroy
  has_many :related_people, through: :family_relationships
  has_one :company_position, class_name: 'CompanyPosition', foreign_key: :person_id, conditions: "company_positions.end_date is null", order: "company_positions.start_date desc"
  has_many :twitter_accounts, class_name: 'Person::TwitterAccount', foreign_key: :person_id, dependent: :destroy
  has_one :twitter_account, class_name: 'Person::TwitterAccount', foreign_key: :person_id, conditions: {'person_twitter_accounts.primary' => true}
  has_many :facebook_accounts, class_name: 'Person::FacebookAccount', foreign_key: :person_id, dependent: :destroy
  has_one  :facebook_account, class_name: 'Person::FacebookAccount', foreign_key: :person_id
  has_many :linkedin_accounts, class_name: 'Person::LinkedinAccount', foreign_key: :person_id, dependent: :destroy
  has_one :linkedin_account, class_name: 'Person::LinkedinAccount', foreign_key: :person_id, conditions: {'person_linkedin_accounts.valid_token' => true}
  has_many :google_accounts, class_name: 'Person::GoogleAccount', foreign_key: :person_id, dependent: :destroy
  has_many :relay_accounts, class_name: 'Person::RelayAccount', foreign_key: :person_id, dependent: :destroy
  has_many :organization_accounts, class_name: 'Person::OrganizationAccount', foreign_key: :person_id, dependent: :destroy
  has_many :key_accounts, class_name: 'Person::KeyAccount', foreign_key: :person_id, dependent: :destroy
  has_many :company_positions, dependent: :destroy
  has_many :companies, through: :company_positions
  has_many :donor_accounts, through: :master_person
  has_many :contact_people, dependent: :destroy
  has_many :contacts, through: :contact_people
  has_many :account_lists, through: :contacts

  accepts_nested_attributes_for :email_addresses, :reject_if => lambda { |e| e[:email].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :phone_numbers, :reject_if => lambda { |p| p[:number].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :family_relationships, :reject_if => lambda { |p| p[:related_contact_id].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :facebook_accounts, :reject_if => lambda { |p| p[:url].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :twitter_accounts, :reject_if => lambda { |p| p[:handle].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :linkedin_accounts, :reject_if => lambda { |p| p[:url].blank? }, :allow_destroy => true


  attr_accessible :first_name, :last_name, :legal_first_name, :birthday_month, :birthday_year, :birthday_day, :anniversary_month, 
                  :anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status, :preferences, :addresses_attributes,
                  :phone_number, :email_address, :middle_name, :phone_numbers_attributes, :family_relationships_attributes, :email,
                  :email_addresses_attributes, :facebook_accounts_attributes, :twitter_accounts_attributes, :linkedin_accounts_attributes,
                  :time_zone, :locale

  before_create :find_master_person
  after_destroy :clean_up_master_person

  validates_presence_of :first_name

  def to_s
    [first_name, last_name].join(' ')
  end

  def add_spouse(spouse)
    relationship = case spouse.gender
                   when 'male'
                     I18n.t('g.relationships_male')[0]
                   when 'female'
                     I18n.t('g.relationships_female')[0]
                   else
                     I18n.t('g.relationships_female')[0] # Default to wife
                   end

    family_relationships.where(related_person_id: spouse.id).first_or_create(relationship: relationship)
  end

  def to_user
    @user ||= User.find(id)
  end

  def email=(val)
    self.email_address = {email: val}
  end

  def email
    primary_email_address || email_addresses.first
  end

  def family_relationships_attributes=(hash)
    hash = hash.with_indifferent_access
    hash.each do |_, attributes|
      if attributes[:id]
        fr = family_relationships.find(attributes[:id])
        if attributes[:_destroy] == '1' || attributes[:related_person_id].blank?
          fr.destroy
        else
          fr.update_attributes(attributes.except(:id, :_destroy))
        end
      else
        FamilyRelationship.add_for_person(self, attributes) if attributes[:related_person_id].present?
      end
    end
  end

  def email_address=(hash)
    hash = hash.with_indifferent_access
    EmailAddress.add_for_person(self, hash) if hash['email'].present?
  end

  def phone_number=(hash)
    hash = hash.with_indifferent_access
    PhoneNumber.add_for_person(self, hash) if hash.with_indifferent_access['number'].present?
  end

  def phone_number
    primary_phone_number
  end

  def self.clone(person)
    new_person = new(person.attributes.with_indifferent_access.except(:id), without_protection: true)
    person.email_addresses.each { |e| new_person.email = e.email }
    person.phone_numbers.each { |pn| new_person.phone_number = pn.attributes.slice(:number, :country_code, :location) }
    new_person.save!
    new_person
  end

  private
  def find_master_person
    unless master_person_id
      self.master_person_id = MasterPerson.find_or_create_for_person(self).id
    end
  end

  def clean_up_master_person
    self.master_person.destroy if (self.master_person.people - [self]).blank?
  end
end
