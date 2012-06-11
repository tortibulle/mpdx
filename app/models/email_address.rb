class EmailAddress < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :email
  before_save :strip_email
  after_save :ensure_only_one_primary

  attr_accessible :email, :primary


  def to_s() email; end

  def self.add_for_person(person, attributes)
    attributes = attributes.with_indifferent_access.except(:_destroy)
    if email = person.email_addresses.find_by_email(attributes['email'].to_s.strip)
      email.update_attributes(attributes)
    else
      attributes['primary'] = (person.email_addresses.present? ? false : true) if attributes['primary'].nil?
      new_or_create = person.new_record? ? :new : :create
      email = person.email_addresses.send(new_or_create, attributes)
    end
    email
  end

  private
    def ensure_only_one_primary
      primary_emails = self.person.email_addresses.where(primary: true)
      primary_emails[0..-2].map {|e| e.update_column(:primary, false)} if primary_emails.length > 1
    end

    def strip_email
      self.email = email.to_s.strip
    end
end
