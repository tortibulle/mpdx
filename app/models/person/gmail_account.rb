class Person::GmailAccount
  def initialize(google_account)
    @google_account = google_account
  end

  def client
    @client ||= @google_account.client
  end

  def gmail
    return false if @google_account.token_expired? && !@google_account.refresh_token!

    begin
      client = Gmail.connect(:xoauth2, @google_account.email, @google_account.token)
      yield client
    ensure
      client.logout
    end
  end

  def folders
    @folders ||= client.labels.all
  end

  def import_emails(account_list)
    return false unless client

    since = @google_account.last_email_sync || 1.hour.ago

    gmail do |g|
      # loop through all contacts, logging email addresses
      email_addresses = []
      account_list.contacts.active.includes(people: :email_addresses).each do |contact|
        contact.people.each do |person|
          person.email_addresses.map(&:email).uniq.each do |email|
            next if email_addresses.include?(email)
            email_addresses << email

            begin
              # sent emails
              sent = g.mailbox('[Gmail]/Sent Mail')
              sent.emails(to: email, after: since).each do |gmail_message|
                log_email(gmail_message, account_list, contact, person, 'Done')
              end

              # received emails
              all = g.mailbox('[Gmail]/All Mail')
              all.emails(from: email, after: since).each do |gmail_message|
                log_email(gmail_message, account_list, contact, person, 'Received')
              end
            rescue Net::IMAP::NoResponseError => e
              # swallow it if the user doesn't have those mailboxes
              raise unless e.message.include?('Unknown Mailbox')
            end
          end
        end
      end
    end
    @google_account.update_attributes(last_email_sync: Time.now)
  end

  def log_email(gmail_message, account_list, contact, person, result)
    message =
      if gmail_message.message.multipart?
        gmail_message.message.text_part
      else
        gmail_message.message
      end
    return unless message

    message = message.body.decoded.to_s.unpack('C*').pack('U*').force_encoding('UTF-8').encode!
    return unless message.strip.present?
    google_email = @google_account.google_emails.find_or_create_by!(google_email_id: gmail_message.msg_id)
    return unless contact.tasks.where(id: google_email.activities.pluck(:id)).empty?
    subject = gmail_message.subject.present? ? gmail_message.subject.truncate(2000, omission: '') : _('No Subject')
    task = contact.tasks.create!(subject: subject,
                                 start_at: gmail_message.envelope.date,
                                 completed: true,
                                 completed_at: gmail_message.envelope.date,
                                 account_list_id: account_list.id,
                                 activity_type: 'Email',
                                 result: result,
                                 remote_id: gmail_message.envelope.message_id,
                                 source: 'gmail')

    task.activity_comments.create!(body: message, person: person)
    google_email.activities << task
    google_email.save!
    task
  end
end
