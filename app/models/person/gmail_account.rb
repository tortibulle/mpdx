class Person::GmailAccount
  def initialize(google_account)
    @google_account = google_account
  end

  def client
    unless @client
      @client = Google::APIClient.new(application_name: 'MPDX', application_version: '1.0')
      @client.authorization.access_token = @google_account.token
    end
    @client
  end

  def gmail
    @google_account.refresh_token! if @google_account.token_expired?

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
    since = @google_account.last_email_sync || 30.days.ago

    gmail do |g|
      # loop through all contacts, logging email addresses
      email_addresses = []
      account_list.contacts.active.includes(people: :email_addresses).each do |contact|
        contact.people.each do |person|
          person.email_addresses.collect(&:email).uniq.each do |email|
            unless email_addresses.include?(email)
              email_addresses << email

              # sent emails
              sent = g.mailbox('[Gmail]/Sent Mail')
              sent.emails(to: email, after: since).each do |gmail_message|
                log_email(gmail_message, account_list, contact, from = @google_account.person_id, to = person.id, 'Done')
              end

              # received emails
              all = g.mailbox('[Gmail]/All Mail')
              all.emails(from: email, after: since).each do |gmail_message|
                log_email(gmail_message, account_list, contact, from = person.id, to = @google_account.person_id, 'Received')
              end
            end
          end
        end
      end
    end
    @google_account.update_attributes(last_email_sync: Time.now)
  end

  def log_email(gmail_message, account_list, contact, from_id, to_id, result)
    if gmail_message.message.multipart?
      message = gmail_message.message.text_part.body.decoded
    else
      message = gmail_message.message.body.decoded
    end
    message = message.to_s.unpack('C*').pack('U*').force_encoding('UTF-8').encode!
    if message.strip.present?
      task = account_list.tasks.where(remote_id: gmail_message.envelope.message_id, source: 'gmail').first

      if task
        task.contacts << contact unless task.contacts.include?(contact)
      else
        task = contact.tasks.create!(subject: gmail_message.subject,
                                      start_at: gmail_message.envelope.date,
                                      completed: true,
                                      completed_at: gmail_message.envelope.date,
                                      account_list_id: account_list.id,
                                      activity_type: 'Email',
                                      result: result,
                                      remote_id: gmail_message.envelope.message_id,
                                      source: 'gmail')

        task.activity_comments.create!(body: message, person_id: from_id)
      end
    end

    account_list.messages.where(remote_id: gmail_message.envelope.message_id, source: 'gmail')
                         .first_or_create!(contact_id: contact.id, from_id: from_id, to_id: to_id,
                                           subject: gmail_message.subject, sent_at: gmail_message.envelope.date,
                                           body: message)
  end
end
