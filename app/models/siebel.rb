class Siebel < DataServer

  def requires_username_and_password?() false; end

  def import_profiles
    designation_profiles = []

    #designation_profiles = @org.designation_profiles.where(user_id: @org_account.person_id)

    # Remove any profiles this user no longer has access to
    #designation_profiles.each do |designation_profile|
      #unless profiles.detect { |profile| profile.name == designation_profile.name && profile.id == designation_profile.code}
        #designation_profile.destroy
      #end
    #end

    profiles.each do |profile|
      designation_profile = Retryable.retryable do
        @org.designation_profiles.where(user_id: @org_account.person_id, name: profile.name, code: profile.id).first_or_create
      end

      designation_profiles << designation_profile

      # Add included designation accounts
      profile.designations.each do |designation|
        find_or_create_designation_account(designation.number, designation_profile, {name: designation.description,
                                                                                     staff_account_id: designation.staff_account_id,
                                                                                     chartfield: designation.chartfield})
      end
    end

    designation_profiles
  end

  def import_profile_balance(profile)
    total = 0
    # the profile balance is the sum of the balances from each designation account in that profile
    profile.designation_accounts.each do |da|
      if da.staff_account_id.present?
        balance = SiebelDonations::Balance.find(employee_ids: da.staff_account_id).first
        da.update_attributes(balance: balance.primary, balance_updated_at: Time.now())
        total += balance.primary
      end
    end
    profile.update_attributes(balance: total, balance_updated_at: Time.now())
    profile
  end

  def import_donors(profile, date_from = nil)
    designation_numbers = profile.designation_accounts.pluck(:designation_number)

    if designation_numbers.present?
      account_list = get_account_list(profile)

      SiebelDonations::Donor.find(having_given_to_designations: designation_numbers.join(',')).each do |siebel_donor|
        donor_account = add_or_update_donor_account(account_list, siebel_donor, profile)

        if siebel_donor.type == 'Business'
          add_or_update_company(account_list, siebel_donor, donor_account)
        end
      end
    end
  end

  def import_donations(profile, start_date = nil, end_date = nil)
    # if no date_from was passed in, use min date from query_ini
    if start_date.blank?
      start_date = @org.minimum_gift_date ? @org.minimum_gift_date : '01/01/2004'
    end

    start_date = Date.strptime(start_date, '%m/%d/%Y').strftime("%Y-%m-%d")

    end_date = end_date ? Date.strptime(end_date, '%m/%d/%Y').strftime("%Y-%m-%d") : Time.now.strftime("%Y-%m-%d")

    profile.designation_accounts.each do |da|
      SiebelDonations::Donation.find(designations: da.designation_number, start_date: start_date,
                                     end_date: end_date).each do |donation|
        add_or_update_donation(donation, da, profile)
      end
    end
  end


  def profiles_with_designation_numbers
    unless @profiles_with_designation_numbers
      @profiles_with_designation_numbers = profiles.collect do |profile|
        {designation_numbers: profile.designations.collect(&:number),
         name: profile.name,
         code: profile.id}
      end
    end
    @profiles_with_designation_numbers
  end

  protected

  def profiles
    unless @profiles
      raise 'No guid for user' unless relay_account = @org_account.user.relay_accounts.first
      @profiles = SiebelDonations::Profile.find(ssoGuid: relay_account.remote_id)
    end
    @profiles
  end

  def find_or_create_designation_account(number, profile, extra_attributes = {})
    @designation_accounts ||= {}
    unless @designation_accounts.has_key?(number)
      da = Retryable.retryable do
        @org.designation_accounts.where(designation_number: number).first_or_create
      end
      profile.designation_accounts << da unless profile.designation_accounts.include?(da)
      da.update_attributes(extra_attributes) if extra_attributes.present?
      @designation_accounts[number] = da
    end
    @designation_accounts[number]
  end

  def add_or_update_donation(siebel_donation, designation_account, profile)
    default_currency = @org.default_currency_code || 'USD'
    donor_account = @org.donor_accounts.find_by_account_number(siebel_donation.donor_id)
    unless donor_account
      Rails.logger.info "Can't find donor account for #{siebel_donation.inspect}"
      return
    end

    Retryable.retryable do
      donation = designation_account.donations.where(remote_id: siebel_donation.id).first_or_initialize
      date = Date.strptime(siebel_donation.donation_date, '%Y-%m-%d')
      donation.attributes = {
        donor_account_id: donor_account.id,
        motivation: siebel_donation.campaign_code,
        payment_method: siebel_donation.payment_method,
        tendered_currency: default_currency,
        donation_date: date,
        amount: siebel_donation.amount,
        tendered_amount: siebel_donation.amount,
        currency: default_currency,
        channel: siebel_donation.channel,
        payment_type: siebel_donation.payment_type
      }
      donation.save!
      donation
    end
  end

  def add_or_update_company(account_list, siebel_donor, donor_account)
    master_company = MasterCompany.find_by_name(siebel_donor.account_name)

    company = @org_account.user.partner_companies.where(master_company_id: master_company.id).first if master_company
    company ||= account_list.companies.new(master_company: master_company)

    contact = siebel_donor.primary_contact || SiebelDonations::Contact.new
    address = siebel_donor.primary_address || SiebelDonations::Address.new
    street = [address.address1, address.address2, address.address3, address.address4].compact.join("\n")

    company.attributes = {
      name: siebel_donor.account_name,
      phone_number: contact.primary_phone_number.try(:phone),
      street: street,
      city: address.city,
      state: address.state,
      postal_code: address.zip
    }
    company.save!

    donor_account.update_attribute(:master_company_id, company.master_company_id) unless donor_account.master_company_id == company.master_company.id
    company
  end

  def add_or_update_donor_account(account_list, donor, profile)
    donor_account = @org.donor_accounts.where(account_number: donor.id).first_or_initialize
    donor_account.attributes = {name: donor.account_name,
                                donor_type: donor.type}
    donor_account.save!

    contact = donor_account.link_to_contact_for(account_list)
    raise 'Failed to link to contact' unless contact

    # Save addresses
    if donor.addresses
      donor.addresses.each { |address| add_or_update_address(address, donor_account) }

      # Make sure the contact has the primary address
      donor.addresses.each { |address| add_or_update_address(address, contact) if address.primary == true }
    end

    # Save people (siebel calls them contacts)
    if donor.contacts
      donor.contacts.each { |person| add_or_update_person(person, donor_account, contact) }
    end

    donor_account
  end

  def add_or_update_person(siebel_person, donor_account, contact)
    master_person_from_source = @org.master_people.where('master_person_sources.remote_id' => siebel_person.id).first

    # If we didn't find someone using the real remote_id, try the "old style"
    unless master_person_from_source
      remote_id = siebel_person.primary ? "#{donor_account.account_number}-1" : "#{donor_account.account_number}-2"
      if master_person_from_source = @org.master_people.where('master_person_sources.remote_id' => remote_id).first
        MasterPersonSource.where(organization_id: @org.id, remote_id: remote_id).update_all(remote_id: siebel_person.id)
      end
    end

    person = donor_account.people.where(master_person_id: master_person_from_source.id).first if master_person_from_source

    person ||= Person.new(master_person: master_person_from_source)

    gender = case siebel_person.sex
             when 'F' then 'female'
             when 'M' then 'male'
             else
               nil
             end

    person.attributes = {
      legal_first_name: siebel_person.first_name,
      first_name: siebel_person.preferred_name || siebel_person.first_name,
      last_name: siebel_person.last_name,
      middle_name: siebel_person.middle_name,
      title: siebel_person.title,
      suffix: siebel_person.suffix,
      gender: gender
    }

    person.master_person_id ||= MasterPerson.find_or_create_for_person(person, donor_account: donor_account).try(:id)
    person.save!

    Retryable.retryable do
      donor_account.people << person unless donor_account.people.include?(person)
      donor_account.master_people << person.master_person unless donor_account.master_people.include?(person.master_person)
    end

    contact_person = contact.add_person(person)

    # create the master_person_source if needed
    unless master_person_from_source
      Retryable.retryable do
        @org.master_person_sources.where(remote_id: siebel_person.id).first_or_create(master_person_id: person.master_person.id)
      end
    end

    # Phone Numbers
    if siebel_person.phone_numbers
      siebel_person.phone_numbers.each { |pn| add_or_update_phone_number(pn, person) }

      # Make sure the contact person has the primary phone number
      siebel_person.phone_numbers.each { |pn| add_or_update_phone_number(pn, contact_person) if pn.primary == true }
    end

    # Email Addresses
    if siebel_person.email_addresses
      siebel_person.email_addresses.each { |email| add_or_update_email_address(email, person) }

      # Make sure the contact person has the primary phone number
      siebel_person.email_addresses.each { |email| add_or_update_email_address(email, contact_person) if email.primary == true }
    end

    [person, contact_person]
  end

  def add_or_update_address(address, object)
    new_address = Address.new(street: [address.address1, address.address2, address.address3, address.address4].compact.join("\n"),
                              city: address.city,
                              state: address.state,
                              postal_code: address.zip,
                              primary_mailing_address: address.primary,
                              seasonal: address.seasonal,
                              location: address.type,
                              remote_id: address.id)

    # If we can match it to an existing address, update that address
    object.addresses.each do |a|
      if a.remote_id == new_address.remote_id || a == new_address
        a.update_attributes(new_address.attributes.select {|k,v| v.present?})
        return a
      end
    end

    # We didn't find a match. save it as a new address
    object.addresses << new_address
    begin
      object.save!
    rescue ActiveRecord::RecordInvalid => e
      raise e.message + " - #{address.inspect}"
    end
  end

  def add_or_update_phone_number(phone_number, person)
    attributes = {
                    number: phone_number.phone,
                    location: phone_number.type.downcase,
                    primary: phone_number.primary,
                    remote_id: phone_number.id
                 }
    if existing_phone = person.phone_numbers.detect { |pn| pn.remote_id == phone_number.id }
      existing_phone.update_attributes(attributes)
    else
      PhoneNumber.add_for_person(person, attributes)
    end
  end

  def add_or_update_email_address(email, person)
    attributes = {
                   email: email.email,
                   primary: email.primary,
                   location: email.type,
                   remote_id: email.id
                 }
    Retryable.retryable do
      if existing_email = person.email_addresses.detect { |e| e.remote_id == email.id }
        begin
          existing_email.update_attributes(attributes)
        rescue ActiveRecord::RecordNotUnique
          # If they already have the email address we're trying to update
          # to, don't do anything
        end
      else
        EmailAddress.add_for_person(person, attributes)
      end
    end
  end


  def check_credentials!() end

end

class SiebelError < StandardError
end
