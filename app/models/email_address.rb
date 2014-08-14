class EmailAddress < ActiveRecord::Base
  include HasPrimary
  @@primary_scope = :person

  has_paper_trail on: [:destroy],
                  meta: { related_object_type: 'Person',
                          related_object_id: :person_id }

  belongs_to :person, touch: true
  validates :email, presence: true, email: true
  validates_uniqueness_of :email, scope: :person_id
  before_save :strip_email
  after_update :sync_with_mail_chimp
  after_destroy :delete_from_mailchimp

  def to_s() email; end

  def self.add_for_person(person, attributes)
    attributes = attributes.with_indifferent_access.except(:_destroy)
    then_cb = proc do |_exception, _handler, _attempts, _retries, _times|
      person.email_addresses.reload
    end

    email = Retryable.retryable on: ActiveRecord::RecordNotUnique,
                                then: then_cb do

      if attributes['id']
        existing_email = person.email_addresses.find(attributes['id'])
        # make sure we're not updating this record to another email that already exists
        if email = person.email_addresses.find { |e| e.email == attributes['email'].to_s.strip && e.id != attributes['id'].to_i }
          email.attributes = attributes
          existing_email.destroy
          email
        else
          existing_email.attributes = attributes
          existing_email
        end
      else
        if email = person.email_addresses.find { |e| e.email == attributes['email'].to_s.strip }
          email.attributes = attributes
        else
          attributes['primary'] ||= !person.email_addresses.present?
          new_or_create = person.new_record? ? :new : :create
          email = person.email_addresses.send(new_or_create, attributes)
        end
        email
      end
    end
    email.save unless email.new_record?
    email
  end

  private

  def strip_email
    self.email = email.to_s.strip
  end

  def contact
    @contact ||= person.contacts.first
  end

  def mail_chimp_account
    @mail_chimp_account ||= contact.try(:account_list).try(:mail_chimp_account)
  end

  def sync_with_mail_chimp
    return unless mail_chimp_account
    if contact && contact.send_email_letter? && !person.optout_enewsletter?
      if primary?
        # If this is the newly designated primary email, we need to
        # change the old one to this one
        if old_email = person.primary_email_address.try(:email)
          mail_chimp_account.queue_update_email(old_email, email)
        else
          mail_chimp_account.queue_subscribe_person(person)
        end
      else
        mail_chimp_account.queue_unsubscribe_email(email)
      end
    else
      begin
        mail_chimp_account.queue_unsubscribe_email(email)
      rescue Gibbon::MailChimpError => e
        logger.info(e)
      end
    end
  end

  def subscribe_to_mail_chimp
    return unless person
    contact = person.contacts.first

    return unless contact && contact.send_email_letter? && mail_chimp_account
    return unless primary? || person.email_addresses.length == 1
    mail_chimp_account.queue_subscribe_person(person)
  end

  def delete_from_mailchimp
    mail_chimp_account.queue_unsubscribe_email(email) if mail_chimp_account
  end
end
