class Person < ActiveRecord::Base
  RELATIONSHIPS_MALE = [_('Husband'), _('Son'), _('Father'), _('Brother'), _('Uncle'), _('Nephew'), _('Cousin (Male)'), _('Grandfather'), _('Grandson')]
  RELATIONSHIPS_FEMALE = [_('Wife'), _('Daughter'), _('Mother'), _('Sister'), _('Aunt'), _('Niece'), _('Cousin (Female)'), _('Grandmother'), _('Granddaughter')]
  TITLES = [_('Mr.'), _('Mrs.'), _('Ms.'), _('Rev.'), _('Hon.'), _('Dr.')]
  SUFFIXES = [_('Jr.'), _('Sr.')]
  MARITAL_STATUSES = [_('Single'), _('Engaged'), _('Married'), _('Separated'), _('Divorced'), _('Widowed')]
  has_paper_trail on: [:destroy],
                  meta: { related_object_type: 'Contact',
                          related_object_id: :contact_id }

  belongs_to :master_person
  has_many :email_addresses, -> { order('email_addresses.primary::int desc') }, dependent: :destroy, autosave: true
  has_one :primary_email_address, -> { where('email_addresses.primary' => true) }, class_name: 'EmailAddress', foreign_key: :person_id
  has_many :phone_numbers, -> { order('phone_numbers.primary::int desc') }, dependent: :destroy
  has_one :primary_phone_number, -> { where('phone_numbers.primary' => true) }, class_name: 'PhoneNumber', foreign_key: :person_id
  has_many :family_relationships, dependent: :destroy
  has_many :related_people, through: :family_relationships
  has_one :company_position, -> { where('company_positions.end_date is null').order('company_positions.start_date desc') }, class_name: 'CompanyPosition', foreign_key: :person_id
  has_many :company_positions, dependent: :destroy
  has_many :twitter_accounts, class_name: 'Person::TwitterAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :twitter_account, -> { where('person_twitter_accounts.primary' => true) }, class_name: 'Person::TwitterAccount', foreign_key: :person_id
  has_many :facebook_accounts, class_name: 'Person::FacebookAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :facebook_account, class_name: 'Person::FacebookAccount', foreign_key: :person_id
  has_many :linkedin_accounts, class_name: 'Person::LinkedinAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :linkedin_account, -> { where('person_linkedin_accounts.valid_token' => true) }, class_name: 'Person::LinkedinAccount', foreign_key: :person_id
  has_many :websites, class_name: 'Person::Website', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_one :website, -> { where('person_websites.primary' => true) }, class_name: 'Person::Website', foreign_key: :person_id
  has_many :google_accounts, class_name: 'Person::GoogleAccount', foreign_key: :person_id, dependent: :destroy, autosave: true
  has_many :relay_accounts, class_name: 'Person::RelayAccount', foreign_key: :person_id, dependent: :destroy
  has_many :organization_accounts, class_name: 'Person::OrganizationAccount', foreign_key: :person_id, dependent: :destroy
  has_many :key_accounts, class_name: 'Person::KeyAccount', foreign_key: :person_id, dependent: :destroy
  has_many :companies, through: :company_positions
  has_many :donor_account_people
  has_many :donor_accounts, through: :donor_account_people
  has_many :contact_people
  has_many :contacts, through: :contact_people
  has_many :account_lists, through: :contacts
  has_many :pictures, as: :picture_of, dependent: :destroy
  has_one :primary_picture, -> { where(primary: true) }, as: :picture_of, class_name: 'Picture'
  has_many :activity_comments, dependent: :destroy
  has_many :messages_sent, class_name: 'Message', foreign_key: :from_id, dependent: :destroy
  has_many :messages_received, class_name: 'Message', foreign_key: :to_id, dependent: :destroy
  has_many :google_contacts, autosave: true

  scope :alive, -> { where.not(deceased: true) }

  accepts_nested_attributes_for :email_addresses, reject_if: -> (e) { e[:email].blank? }, allow_destroy: true
  accepts_nested_attributes_for :phone_numbers, reject_if: -> (p) { p[:number].blank? }, allow_destroy: true
  accepts_nested_attributes_for :family_relationships, reject_if: -> (p) { p[:related_contact_id].blank? }, allow_destroy: true
  accepts_nested_attributes_for :facebook_accounts, reject_if: -> (p) { p[:url].blank? }, allow_destroy: true
  accepts_nested_attributes_for :twitter_accounts, reject_if: -> (p) { p[:screen_name].blank? }, allow_destroy: true
  accepts_nested_attributes_for :linkedin_accounts, reject_if: -> (p) { p[:url].blank? }, allow_destroy: true
  accepts_nested_attributes_for :pictures, reject_if: -> (p) { p[:image].blank? && p[:image_cache].blank? }, allow_destroy: true
  accepts_nested_attributes_for :websites, reject_if: -> (p) { p[:url].blank? }, allow_destroy: true

  PERMITTED_ATTRIBUTES = [
    :first_name, :legal_first_name, :last_name, :birthday_month, :birthday_year, :birthday_day,
    :anniversary_month, :anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status,
    :middle_name, :profession, :deceased, :optout_enewsletter, :occupation, :employer, :_destroy, :id,
    {
      email_address: :email,
      phone_number: :number,
      email_addresses_attributes: [:email, :historic, :primary, :_destroy, :id],
      phone_numbers_attributes: [:number, :location, :primary, :_destroy, :id],
      linkedin_accounts_attributes: [:url, :_destroy, :id],
      facebook_accounts_attributes: [:url, :_destroy, :id],
      twitter_accounts_attributes: [:screen_name, :_destroy, :id],
      pictures_attributes: [:image, :image_cache, :primary, :_destroy, :id],
      family_relationships_attributes: [:related_person_id, :relationship, :_destroy, :id],
      websites_attributes: [:url, :primary, :_destroy, :id]
    }
  ]

  before_create :find_master_person
  after_destroy :clean_up_master_person, :clean_up_contact_people
  after_commit :sync_with_mailchimp
  before_save :deceased_check
  after_save :touch_contacts

  validates :first_name, presence: true

  def to_s
    [first_name, last_name].join(' ')
  end

  def to_s_last_first
    [last_name, first_name].join(', ')
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
    family_relationships.where(relationship: %w(Husband Wife)).first.try(:related_person)
  end

  def to_user
    @user ||= User.find(id)
  end

  def email=(val)
    self.email_address = { email: val, primary: true }
  end

  def email
    primary_email_address || email_addresses.first
  end

  def deceased_check
    return unless deceased_changed? && self.deceased?

    self.optout_enewsletter = true

    contacts.each do |c|
      # Only update the greeting, etc. if this contact has a non-deceased other person (e.g. a spouse)
      next unless c.people.where(deceased: false).where('people.id <> ?', id).count > 0

      contact_updates = {}

      # We need to access the field value directly via c[:greeting] because c.greeting defaults to the first name
      # even if the field is nil. That causes an infinite loop here where it keeps trying to remove the first name
      # from the greeting but it keeps getting defaulted back to having it.
      if c[:greeting].present? && c[:greeting].include?(first_name)
        contact_updates[:greeting] = c.greeting.sub(first_name, '').sub(/ #{_('and')} /, ' ').strip
      end
      contact_updates[:envelope_greeting] = '' if c[:envelope_greeting].present?

      if c.name.include?(first_name)
        contact_updates[:name] = c.name.sub(first_name, '').sub(/ & | #{_('and')} /, '').strip
      end

      if c.primary_person_id == id && c.people.count > 1
        # This only modifies associated people via update_column, so we can call it directly
        c.clear_primary_person
      end

      next if contact_updates == {}

      contact_updates[:updated_at] = Time.now
      # Call update_columns instead of save because a save of a contact can trigger saving its people which
      # could eventually call this very deceased_check method and cause an infinite recursion.
      c.update_columns(contact_updates)
    end
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

      remote_id = Person::FacebookAccount.get_id_from_url(attributes['url'])
      next unless remote_id
      attributes['remote_id'] = remote_id
      if facebook_ids.include?(attributes['remote_id'])
        hash.delete(key)
      else
        facebook_ids << attributes['remote_id']
      end
    end

    hash.each do |_, attributes|
      if attributes['id']
        fa = facebook_accounts.find(attributes['id'])
        if attributes['_destroy'] == '1'
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
    if hash['_destroy'] == '1'
      email_addresses.find(hash['id']).destroy
    else
      EmailAddress.add_for_person(self, hash) if hash['email'].present?
    end
  end

  def email_addresses_attributes=(attributes)
    case
    when attributes.is_a?(Hash)
      attributes.each do |_, v|
        self.email_address = v
      end
    when attributes.is_a?(Array)
      attributes.each do |v|
        self.email_address = v
      end
    else
      super
    end
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
    self.phone_number = { number: number }
  end

  def merge_phone_numbers
    phone_numbers.reload.each do |phone_number|
      other_phone = phone_numbers.find { |pn|
        pn.id != phone_number.id &&
        pn == phone_number
      }
      next unless other_phone
      phone_number.merge(other_phone)
      merge_phone_numbers
      return
    end
  end

  def merge(other)
    Person.transaction(requires_new: true) do
      other.messages_sent.update_all(from_id: id)
      other.messages_received.update_all(to_id: id)

      %w(phone_numbers company_positions).each do |relationship|
        other.send(relationship.to_sym).each do |other_rel|
          next if send(relationship.to_sym).find { |rel| rel == other_rel }
          other_rel.update_column(:person_id, id)
        end
      end

      merge_phone_numbers

      # handle a few things separately to check for duplicates
      %w(twitter_accounts facebook_accounts linkedin_accounts
         google_accounts relay_accounts organization_accounts).each do |relationship|
        other.send(relationship).each do |record|
          next if send(relationship).where(person_id: id, remote_id: record.remote_id).any?
          record.update_attributes!(person_id: id)
        end
      end

      other.email_addresses.each do |email_address|
        next if email_addresses.find_by_email(email_address.email)
        email_address.update_attributes(person_id: id)
      end

      other.pictures.each do |picture|
        picture.picture_of = self
        picture.save
      end

      # because we're in a transaction, we need to keep track of which relationships we've updated so
      # we don't create duplicates on the next part
      FamilyRelationship.where(related_person_id: other.id).each do |fr|
        next if FamilyRelationship.where(person_id: fr.person_id, related_person_id: id).first
        fr.update_attributes(related_person_id: id)
      end

      FamilyRelationship.where(person_id: other.id).each do |fr|
        next if FamilyRelationship.where(related_person_id: fr.person_id, person_id: id)
        fr.update_attributes(person_id: id)
      end

      # Copy fields over updating any field that's blank on the winner
      [:first_name, :last_name, :legal_first_name, :birthday_month, :birthday_year, :birthday_day, :anniversary_month,
       :anniversary_year, :anniversary_day, :title, :suffix, :gender, :marital_status,
       :middle_name].each do |field|
        next unless send(field).blank? && other.send(field).present?
        send("#{field}=".to_sym, other.send(field))
      end

      # copy over master person sources from loser
      other.master_person.master_person_sources.each do |source|
        master_person.master_person_sources.where(organization_id: source.organization_id, remote_id: source.remote_id).first_or_initialize
      end

      # Assume the winner has the nickname and the loser has the full name, and increment the times merged to
      # track which nicknames are useful and to add new nicknames over time.
      Nickname.increment_times_merged(other.first_name, first_name)

      other.reload
      other.destroy
    end

    save(validate: false)
  end

  def self.clone(person)
    new_person = new(person.attributes.except('id', 'access_token', 'created_at', 'current_sign_in_at', 'current_sign_in_ip', 'last_sign_in_at', 'last_sign_in_ip', 'preferences',
                                              'sign_in_count'))
    person.email_addresses.each { |e| new_person.email = e.email }
    person.phone_numbers.each { |pn| new_person.phone_number = pn.attributes.slice(:number, :country_code, :location) }
    new_person.save(validate: false)
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

  def not_same_as?(other)
    not_duplicated_with.to_s.split(',').include?(other.id.to_s) || other.not_duplicated_with.to_s.split(',').include?(id.to_s)
  end

  private

  def find_master_person
    unless master_person_id
      self.master_person_id = MasterPerson.find_or_create_for_person(self).id
    end
  end

  def clean_up_master_person
    master_person.destroy if master_person && (master_person.people - [self]).blank?
  end

  def clean_up_contact_people
    contact_people.destroy_all
  end

  def mail_chimp_account
    @mail_chimp_account ||= contact.account_list.mail_chimp_account if contact
  end

  def sync_with_mailchimp
    if mail_chimp_account && contact && contact.send_email_letter? && !self.optout_enewsletter?
      mail_chimp_account.queue_subscribe_person(self)
    end
  end

  def touch_contacts
    contacts.map(&:touch) if sign_in_count == 0
  end
end
