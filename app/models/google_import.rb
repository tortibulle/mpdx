class GoogleIntegration < ActiveRecord::Base

  def initialize(import)
    @user = import.user
    @import = import
    @account_list = import.account_list
  end

  def import
    import_contacts
  end

  def import_emails
    @user.google_accounts.each do |google_account|
      begin
        google_account.update_column(:downloading, true)

        google_account.contacts.each do |google_contact|

        end
      ensure
        google_account.update_column(:downloading, false)
        google_account.update_column(:last_download, Time.now)
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
    fb_person = account_list.people.includes(:google_account).where('person_google_accounts.remote_id' => friend.identifier).first

    # If we can't find a contact with this fb account, see if we have a contact with the same name and no fb account
    unless fb_person
      fb_person = account_list.people.includes(:google_account).where('person_google_accounts.remote_id' => nil,
                                                                        'people.first_name' => friend.first_name,
                                                                        'people.last_name' => friend.last_name).first

    end

    if fb_person
      fb_person.update_attributes(person_attributes)
    else
      # Look for a matching person auth an authenticated fb account
      account = Person::googleAccount.where(remote_id: friend.identifier, authenticated: true).first
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

    unless fb_person.google_accounts.pluck(:remote_id).include?(friend.identifier.to_i)
      # Create a google account
      begin
        fb_person.google_accounts.create!(remote_id: friend.identifier,
                                            authenticated: true,
                                            first_name: friend.first_name,
                                            last_name: friend.last_name)
      rescue ActiveRecord::RecordNotUnique
      end
    end

    # add phone number and email if available
    fb_person.email = friend.email if friend.email.present?
    fb_person.phone_number = {number: friend.mobile_phone, location: 'mobile'} if friend.mobile_phone.present?
    fb_person.save

    fb_person
  end

end
