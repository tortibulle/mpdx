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

      if @import.import_by_group
        @import.groups.each do |group_id|
          group = GoogleContactsApi::Group.new({ 'id' => { '$t' => group_id } }, nil,
                                               google_account.contacts_api_user.api)
          delimiter = @import.tags.present? && @import.group_tags[group_id].present? ? ',' : ''
          import_contacts_batch(group.contacts, @import.group_tags[group_id] + delimiter + @import.tags)
        end
      else
        import_contacts_batch(google_account.contacts, @import.tags)
      end

      @import.tags.present?
    ensure
      google_account.update_column(:downloading, false)
      google_account.update_column(:last_download, Time.now)
    end
  end

  def import_contacts_batch(google_contacts, tags)
    google_contacts.each do |google_contact|
      begin
        next unless google_contact.given_name

        person = create_or_update_person(google_contact, @account_list)

        contact = @account_list.contacts.with_person(person).first

        unless contact
          # Create a contact
          name = "#{person.last_name}, #{person.first_name}"
          contact = @account_list.contacts.find_or_create_by(name: name)
        end

        update_contact_info(contact, google_contact)

        contact.tag_list.add(tags, parse: true) if tags.present?
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
  end

  def build_address_array(google_contact, contact, override)
    addresses = []
    google_contact.addresses.each do |location|
      street = location[:street]
      city = location[:city]
      state = location[:region]
      postal_code = location[:postcode]
      country = location[:country] == 'United States of America' ? 'United States' : location[:country]
      if [street, city, state, postal_code].any?(&:present?)
        primary_address = location[:primary] if override
        if primary_address && contact
          contact.addresses.each do |address|
            unless address.street == street && address.city == city && address.state == state && address.postal_code == postal_code && address.country == country
              address.primary_mailing_address = false
              address.save
            end
          end
        end

        if location[:rel] == 'work'
          address_location = 'Business'
        elsif location[:rel] == 'home'
          address_location = 'Home'
        else
          address_location = 'Other'
        end

        addresses << {
          street: street,
          city: city,
          state: state,
          postal_code: postal_code,
          country: country,
          location: address_location,
          primary_mailing_address: primary_address
        }
      end
    end

    addresses
  end

  def update_contact_info(contact, google_contact)
    contact.addresses_attributes = build_address_array google_contact, contact, @import.override
  end

  def create_or_update_person(google_contact, account_list)
    person_attributes = {
      first_name: google_contact.given_name,
      last_name: google_contact.family_name
    }.select { |_, v| v.present? }

    # First from my contacts
    person = account_list.people.includes(:google_accounts).where('person_google_accounts.remote_id' => google_contact.id).first

    # If we can't find a contact with this google account, see if we have a contact with the same name and no google account
    unless person
      person = account_list.people.includes(:google_accounts).where('person_google_accounts.remote_id' => nil,
                                                                    'people.first_name' => google_contact.given_name,
                                                                    'people.last_name' => google_contact.family_name).first
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
    google_contact.emails_full.each do |email_fields|
      person.email_address = {
        email: email_fields[:address],
        location: email_fields[:rel],
        primary: email_fields[:primary]
      }
    end
    google_contact.phone_numbers_full.each do |number_fields|
      person.phone_number = {
        number: number_fields[:number],
        location: number_fields[:rel],
        primary: number_fields[:primary]
      }
    end
    person.save

    person
  end
end
