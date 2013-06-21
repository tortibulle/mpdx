class Person < ActiveRecord::Base
  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: 'Contact',
                             related_object_id: :contact_id }

  belongs_to :master_person
  has_many :email_addresses, dependent: :destroy, autosave: true
  has_one :primary_email_address, class_name: 'EmailAddress', foreign_key: :person_id, conditions: {'email_addresses.primary' => true}
  has_many :phone_numbers, dependent: :destroy
  has_one :primary_phone_number, class_name: 'PhoneNumber', foreign_key: :person_id, conditions: {'phone_numbers.primary' => true}
  has_many :family_relationships, dependent: :destroy
  has_many :related_people, through: :family_relationships
  has_one :company_position, class_name: 'CompanyPosition', foreign_key: :person_id, conditions: "company_positions.end_date is null", order: "company_positions.start_date desc"
  has_many :company_positions, dependent: :destroy
  has_many :twitter_accounts, class_name: 'Person::TwitterAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :twitter_account, class_name: 'Person::TwitterAccount', foreign_key: :person_id, conditions: {'person_twitter_accounts.primary' => true}
  has_many :facebook_accounts, class_name: 'Person::FacebookAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one  :facebook_account, class_name: 'Person::FacebookAccount', foreign_key: :person_id
  has_many :linkedin_accounts, class_name: 'Person::LinkedinAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :linkedin_account, class_name: 'Person::LinkedinAccount', foreign_key: :person_id, conditions: {'person_linkedin_accounts.valid_token' => true}
  has_many :google_accounts, class_name: 'Person::GoogleAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_many :relay_accounts, class_name: 'Person::RelayAccount', foreign_key: :person_id, dependent: :destroy
  has_many :organization_accounts, class_name: 'Person::OrganizationAccount', foreign_key: :person_id, dependent: :destroy
  has_many :key_accounts, class_name: 'Person::KeyAccount', foreign_key: :person_id, dependent: :destroy
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


  #attr_accessible :first_name, :last_name, :legal_first_name, :birthday_month, :birthday_year, :birthday_day, :anniversary_month,
                  #:anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status, :preferences, :addresses_attributes,
                  #:phone_number, :email_address, :middle_name, :phone_numbers_attributes, :family_relationships_attributes, :email,
                  #:email_addresses_attributes, :facebook_accounts_attributes, :twitter_accounts_attributes, :linkedin_accounts_attributes,
                  #:time_zone, :locale, :phone

  before_create :find_master_person
  after_destroy :clean_up_master_person
  after_commit  :sync_with_mailchimp
  after_save :touch_contacts

  validates_presence_of :first_name

  def to_s
    [first_name, last_name].join(' ')
  end

  def touch
    super
    touch_contacts
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

    begin
      family_relationships.where(related_person_id: spouse.id).first_or_create(relationship: relationship)
    rescue ActiveRecord::RecordNotUnique
    end
  end

  def spouse
    family_relationships.where(relationship: ['Husband','Wife']).first.try(:related_person)
  end

  def to_user
    @user ||= User.find(id)
  end

  def email=(val)
    self.email_address = {email: val, primary: true}
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
          begin
            fr.update_attributes(attributes.except(:id, :_destroy))
          rescue ActiveRecord::RecordNotUnique
            fr.destroy
          end
        end
      else
        FamilyRelationship.add_for_person(self, attributes) if attributes[:related_person_id].present?
      end
    end
  end

  # Augment the built-in rails method to prevent duplicate facebook accounts
  def facebook_accounts_attributes=(hash)
    facebook_ids = facebook_accounts.pluck(:remote_id)

    hash.each do |key, attributes|
      next if attributes['_destroy'] == '1'

      attributes['remote_id'] = Person::FacebookAccount.get_id_from_url(attributes['url'])
      if facebook_ids.include?(attributes['remote_id'])
        hash.delete(key)
      else
        facebook_ids << attributes['remote_id']
      end
    end

    hash.each do |_, attributes|
      if attributes['id']
        fa = facebook_accounts.find(attributes['id'])
        if attributes['_destroy'] == '1' || attributes['remote_id'].blank?
          fa.destroy
        else
          fa.update_attributes(attributes.except('id', '_destroy'))
        end
      else
        unless attributes['_destroy'] == '1' || attributes['remote_id'].blank?
          fa = facebook_accounts.new(attributes.except('_destroy'))
          fa.save unless new_record?
        end
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

  def phone
    primary_phone_number.try(:number)
  end

  def phone=(number)
    self.phone_number = {number: number}
  end

  def merge_phone_numbers
    phone_numbers.reload.each do |phone_number|
      if other_phone = phone_numbers.detect { |pn| pn.id != phone_number.id &&
                                                   pn == phone_number }
        phone_number.merge(other_phone)
        merge_phone_numbers
        return
      end
    end
  end

  def merge(other)
    Person.transaction(:requires_new => true) do
      %w[phone_numbers company_positions].each do |relationship|
        other.send(relationship.to_sym).each do |other_rel|
          unless send(relationship.to_sym).detect { |rel| rel == other_rel }
            other_rel.update_column(:person_id, id)
          end
        end
      end

      merge_phone_numbers

      # handle a few things separately to check for duplicates
      %w[twitter_accounts facebook_accounts linkedin_accounts
        google_accounts relay_accounts organization_accounts].each do |relationship|
        other.send(relationship).each do |record|
          unless send(relationship).where(person_id: id, remote_id: record.remote_id).any?
            record.update_attributes!(person_id: id)
          end
        end
      end

      other.email_addresses.each do |email_address|
        unless email_addresses.find_by_email(email_address.email)
          email_address.update_attributes({person_id: id}, without_protection: true)
        end
      end

      # because we're in a transaction, we need to keep track of which relationships we've updated so
      # we don't create duplicates on the next part
      FamilyRelationship.where(related_person_id: other.id).each do |fr|
        unless FamilyRelationship.where(person_id: fr.person_id, related_person_id: id).first
          fr.update_attributes({related_person_id: id}, without_protection: true)
        end
      end

      FamilyRelationship.where(person_id: other.id).each do |fr|
        unless FamilyRelationship.where(related_person_id: fr.person_id, person_id: id)
          fr.update_attributes({person_id: id}, without_protection: true)
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
    new_person = new(person.attributes.except('id', 'access_token', 'created_at', 'current_sign_in_at', 'current_sign_in_ip', 'last_sign_in_at', 'last_sign_in_ip', 'preferences',
                                              'sign_in_count'), without_protection: true)
    person.email_addresses.each { |e| new_person.email = e.email }
    person.phone_numbers.each { |pn| new_person.phone_number = pn.attributes.slice(:number, :country_code, :location) }
    new_person.save!
    new_person
  end

  def contact
    @contact ||= contacts.first
  end

  def contact_id
    contact.try(:id)
  end

  def to_person
    self
  end


  private
  def find_master_person
    unless master_person_id
      self.master_person_id = MasterPerson.find_or_create_for_person(self).id
    end
  end

  def clean_up_master_person
    self.master_person.destroy if self.master_person && (self.master_person.people - [self]).blank?
  end

  def mail_chimp_account
    @mail_chimp_account ||= contact.account_list.mail_chimp_account if contact
  end

  def sync_with_mailchimp
    if mail_chimp_account && contact && contact.send_email_letter?
      queue_subscribe_person(self)
    end
  end

  def touch_contacts
    contacts.map(&:touch) if sign_in_count == 0
  end

end
