class FacebookImport

  def initialize(import)
    @user = import.user
    @import = import
    @account_list = import.account_list
  end

  def import_contacts
    @user.facebook_accounts.each do |facebook_account|
      begin
        facebook_account.update_column(:downloading, true)

        FbGraph::User.new(facebook_account.remote_id, access_token: facebook_account.token).friends.each do |f|
          # Add to friend set
          begin
            begin
              sleep 1 unless Rails.env.test? # facebook apparently limits api calls to 600 calls every 600s
              friend = f.fetch
            rescue OpenSSL::SSL::SSLError, HTTPClient::ConnectTimeoutError, HTTPClient::ReceiveTimeoutError
              puts "retrying on line #{__LINE__}"
              sleep 5
              retry
            rescue FbGraph::Unauthorized
              puts "retrying on line #{__LINE__}"
              sleep 60
              retry
            end

            facebook_account.friends << friend.identifier

            # Try to match an existing person
            fb_person = create_or_update_person(friend, @account_list)

            contact = @account_list.contacts.with_person(fb_person).first

            # Look for a spouse
            if friend.relationship_status == 'Married' && friend.significant_other.present?
              # skip this person if they're my spouse
              next if friend.significant_other.identifier == facebook_account.remote_id.to_s

              spouse = friend.significant_other.fetch(access_token: facebook_account.token)
              sleep 1 unless Rails.env.test?

              fb_spouse = create_or_update_person(spouse, @account_list)

              # if we don't already have a contact, maybe the spouse is one
              contact ||= @account_list.contacts.with_person(fb_spouse).first

              fb_person.add_spouse(fb_spouse)
            end

            unless contact
              # Create a contact
              name = "#{fb_person.last_name}, #{fb_person.first_name}"
              name += " & #{fb_spouse.first_name}" if fb_spouse

              contact = @account_list.contacts.find_or_create_by_name(name)
            end

            contact.tag_list.add(@import.tags, parse: true) if @import.tags.present?
            contact.save

            contact.people.reload
            if fb_spouse
              contact.people << fb_spouse unless contact.person_ids.include?(fb_spouse.id)
            end
            contact.people << fb_person unless contact.person_ids.include?(fb_person.id)

          rescue => e
            Airbrake.raise_or_notify(e)
            next
          end

        end
      ensure
        facebook_account.update_column(:downloading, false)
      end
    end
  end


  def create_or_update_person(friend, account_list)
    birthday = friend.raw_attributes['birthday'].to_s.split('/')

    person_attributes = {
      first_name: friend.first_name,
      last_name: friend.last_name,
      middle_name: friend.middle_name,
      gender: friend.gender,
      birthday_month: birthday[0],
      birthday_day: birthday[1],
      birthday_year: birthday[2],
      marital_status: friend.relationship_status
    }.select { |_, v| v.present? }


    # First from my contacts
    fb_person = account_list.people.includes(:facebook_account).where('person_facebook_accounts.remote_id' => friend.identifier).first

    # If we can't find a contact with this fb account, see if we have a contact with the same name and no fb account
    unless fb_person
      fb_person = account_list.people.includes(:facebook_account).where('person_facebook_accounts.remote_id' => nil, 
                                                                        'people.first_name' => friend.first_name,
                                                                        'people.last_name' => friend.last_name).first

    end

    if fb_person
      fb_person.update_attributes(person_attributes)
    else
      # Look for a matching person auth an authenticated fb account
      account = Person::FacebookAccount.where(remote_id: friend.identifier, authenticated: true).first
      if account
        # Create a new person using the same master_person
        fb_person = account.person.master_person.people.create(person_attributes)
      else
        begin
          fb_person = Person.create!(person_attributes)
        rescue ActiveRecord::RecordInvalid => e
          raise person_attributes.inspect
        end
      end

    end

    unless fb_person.facebook_accounts.pluck(:remote_id).include?(friend.identifier.to_i)
      # Create a facebook account
      fb_person.facebook_accounts.create!(remote_id: friend.identifier,
                                          authenticated: true,
                                          first_name: friend.first_name,
                                          last_name: friend.last_name)
    end

    # add phone number and email if available
    fb_person.email = friend.email if friend.email.present?
    fb_person.phone_number = {number: friend.mobile_phone, location: 'mobile'} if friend.mobile_phone.present?
    fb_person.save

    fb_person
  end

end
