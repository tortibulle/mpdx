class EmailAddress < ActiveRecord::Base
  belongs_to :person
  validates_presence_of :email
  before_save :strip_email
  after_update :sync_with_mail_chimp
  after_commit :ensure_only_one_primary, :subscribe_to_mail_chimp
  after_destroy :delete_from_mailchimp

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
    if person.email_addresses.present?
      primary_emails = self.person.email_addresses.where(primary: true)
      if primary_emails.blank?
        person.email_addresses.last.update_column(:primary, true)
      elsif primary_emails.length > 1
        if primary_emails.include?(self)
          (primary_emails - [self]).map {|e| e.update_column(:primary, false)}
        else
          primary_emails[0..-2].map {|e| e.update_column(:primary, false)}
        end
      end
    end
  end

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
    if mail_chimp_account
      if contact && contact.send_email_letter?

        # If the value of the email field changed, unsubscribe the old
        if changed.include?('email') && email_was.present?
          mail_chimp_account.queue_update_email(email_was, email)
        end

        if changed.include?('primary')
          if primary?
            # If this is the newly designated primary email, we need to
            # change the old one to this one
            if old_email = person.primary_email_address.try(:email)
              mail_chimp_account.queue_update_email(old_email, email)
            else
              mail_chimp_account.queue_subscribe_person(person)
            end
          else
            # If this used to be the primary, and now isn't, that means
            # something else is now the primary and will take care of
            # updating itself.
          end
        end
      else
        begin
          mail_chimp_account.queue_unsubscribe_email(email)
        rescue Gibbon::MailChimpError => e
          logger.info(e)
        end
      end
    end

  end

  def subscribe_to_mail_chimp
    if person
      contact = person.contacts.first

      if contact && contact.send_email_letter? &&
          mail_chimp_account &&
          (primary? || person.email_addresses.length == 1)
        mail_chimp_account.queue_subscribe_person(person)
      end
    end

  end

  def delete_from_mailchimp
    if mail_chimp_account
      mail_chimp_account.queue_unsubscribe_email(email)
    end
  end

end
