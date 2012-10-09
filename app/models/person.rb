class Person < ActiveRecord::Base

  belongs_to :master_person
  has_many :email_addresses, dependent: :destroy
  has_one :primary_email_address, class_name: 'EmailAddress', foreign_key: :person_id, conditions: {'email_addresses.primary' => true}
  has_many :phone_numbers, dependent: :destroy
  has_one :primary_phone_number, class_name: 'PhoneNumber', foreign_key: :person_id, conditions: {'phone_numbers.primary' => true}
  has_many :family_relationships, dependent: :destroy
  has_many :related_people, through: :family_relationships
  has_one :company_position, class_name: 'CompanyPosition', foreign_key: :person_id, conditions: "company_positions.end_date is null", order: "company_positions.start_date desc"
  has_many :company_positions, dependent: :destroy
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
  has_many :companies, through: :company_positions
  has_many :donor_accounts, through: :master_person
  has_many :contact_people
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
  after_commit  :sync_with_mailchimp

  validates_presence_of :first_name

  def to_s
    [first_name, last_name].join(' ')
  end

  def add_spouse(spouse)
    relationship = case spouse.gender
                   when 'male'
                     'Husband'
                   when 'female'
                     'Wife'
                   else
                     'Wife' # Default to wife
                   end

    family_relationships.where(related_person_id: spouse.id).first_or_create(relationship: relationship)
  end

  def spouse
    family_relationships.where(relationship: ['Husband','Wife']).first.try(:related_person)
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

  def merge(other)
    Person.transaction do
      %w[phone_numbers company_positions twitter_accounts facebook_accounts linkedin_accounts
        google_accounts relay_accounts organization_accounts contact_people].each do |relationship|
        other.send(relationship.to_sym).update_all(person_id: id)
      end

      # handle emails separately to check for duplicates
      other.email_addresses.each do |email_address|
        unless email_addresses.find_by_email(email_address.email)
          email_address.update_attributes({person_id: id}, without_protection: true)
        end
      end
      FamilyRelationship.where(related_person_id: other.id).each do |fr|
        unless FamilyRelationship.where(person_id: fr.person_id, related_person_id: id).first
          fr.update_attributes(related_person_id: id)
        end
      end

      FamilyRelationship.where(person_id: other.id).each do |fr|
        unless FamilyRelationship.where(related_person_id: fr.person_id, person_id: id).first
          fr.update_attributes(person_id: id)
        end
      end

      # Copy fields over updating any field that's blank on the winner
      [:first_name, :last_name, :legal_first_name, :birthday_month, :birthday_year, :birthday_day, :anniversary_month,
       :anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status,
       :middle_name,].each do |field|
        if send(field).blank? && other.send(field).present?
          send("#{field}=".to_sym, other.send(field))
        end
      end

      save(validate: false)
      other.reload
      other.destroy
    end
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

  def contact
    @contact ||= person.contacts.first
  end

  def mail_chimp_account
    @mail_chimp_account ||= contact.account_list.mail_chimp_account
  end

  def sync_with_mailchimp
    if mail_chimp_account && contact.send_email_letter?
      queue_subscribe_person(self)
    end
  end


end
