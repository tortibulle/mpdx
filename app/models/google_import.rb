class GoogleImport
  def initialize(import)
    @user = import.user
    @import = import
    @account_list = import.account_list
  end

  def import
    import_contacts
  end

  def import_contacts
    return false unless @import.source_account_id

    google_account = @user.google_accounts.find(@import.source_account_id)
    begin
      google_account.update_column(:downloading, true)

      google_account.contacts.each do |google_contact|
        begin
          # Try to match an existing person
          person = create_or_update_person(google_contact, @account_list)
          next unless person

          contact = @account_list.contacts.with_person(person).first

          unless contact
            # Create a contact
            name = "#{person.last_name}, #{person.first_name}"
            contact = @account_list.contacts.find_or_create_by(name: name)
          end

          contact.tag_list.add(@import.tags, parse: true) if @import.tags.present?
          contact.save

          contact.people.reload

          begin
            contact.people << person unless contact.people.include?(person)
          rescue ActiveRecord::RecordNotUnique
          end
        rescue => e
          Airbrake.raise_or_notify(e)
          next
        end
      end
    ensure
      google_account.update_column(:downloading, false)
      google_account.update_column(:last_download, Time.now)
    end
  end

  def create_or_update_person(google_contact, account_list)
    person_attributes = {
      first_name: google_contact['gd$name'].to_h['gd$givenName'].to_h['$t'],
      last_name: google_contact['gd$name'].to_h['gd$familyName'].to_h['$t'],
      email: google_contact.primary_email
    }.select { |_, v| v.present? }

    return unless person_attributes[:first_name].present?

    # First from my contacts
    person = account_list.people.includes(:google_accounts).where('person_google_accounts.remote_id' => google_contact.id).first

    # If we can't find a contact with this google account, see if we have a contact with the same name and no google account
    unless person
      person = account_list.people.includes(:google_accounts).where('person_google_accounts.remote_id' => nil,
                                                                    'people.first_name' => google_contact.first_name,
                                                                    'people.last_name' => google_contact.last_name).first
    end

    if person
      person.update_attributes(person_attributes)
    else
      # Look for a matching person auth an authenticated google account
      account = Person::GoogleAccount.where(remote_id: google_contact.id, authenticated: true).first
      if account
        # Create a new person using the same master_person
        person = account.person.master_person.people.create(person_attributes)
      else
        begin
          person = Person.create!(person_attributes)
        rescue ActiveRecord::RecordInvalid
          raise person_attributes.inspect
        end
      end
    end

    unless person.google_accounts.pluck(:remote_id).include?(google_contact.identifier.to_i)
      # Create a google account
      begin
        person.google_accounts.create!(remote_id: google_contact.id,
                                       email: person_attributes[:email],
                                       authenticated: true)
      rescue ActiveRecord::RecordNotUnique
      end
    end

    # add phone number and email if available
    person.email = google_contact.email if google_contact.email.present?
    person.phone_number = { number: google_contact.mobile_phone, location: 'mobile' } if google_contact.mobile_phone.present?
    person.save

    person
  end
end
