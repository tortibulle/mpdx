class MasterPerson < ActiveRecord::Base
  has_many :people, dependent: :destroy
  has_many :master_person_donor_accounts, dependent: :destroy
  has_many :master_person_sources, dependent: :destroy
  has_many :donor_accounts, through: :master_person_donor_accounts

  def self.find_or_create_for_person(person, extra = {})
    if master_person = find_for_person(person, extra = {})
      return master_person
    end
    mp = create!
    if donor_account = extra[:donor_account]
      mp.donor_accounts << donor_account
      mp.master_person_sources.create(organization_id: donor_account.organization_id, remote_id: extra[:remote_id]) if extra[:remote_id]
    end
  end

  def self.find_for_person(person, extra = {})
    # Start by looking for a person with the same email address (since that's our one true unique field)
    person.email_addresses.each do |email_address|
      if other_person = Person.where('people.first_name' => person.first_name,
                                     'people.last_name' => person.last_name,
                                     'people.suffix' => person.suffix,
                                     'email_addresses.email' => email_address.email)
                              .where('people.middle_name = ? OR people.middle_name is null', person.middle_name)
                              .joins(:email_addresses)
                              .first
        return other_person.master_person
      end
    end

    # if we have an exact match on name and phone number, that's also pretty good
    person.phone_numbers.each do |phone_number|
      phone_number.clean_up_number
      if phone_number.number.present?
        if other_person = Person.where('people.first_name' => person.first_name,
                                       'people.last_name' => person.last_name,
                                       'people.suffix' => person.suffix,
                                       'phone_numbers.number' => phone_number.number,
                                       'phone_numbers.country_code' => phone_number.country_code)
                                .where('people.middle_name = ? OR people.middle_name is null', person.middle_name)
                                .joins(:phone_numbers).first
          return other_person.master_person
        end
      end
    end

    # If we have a donor account to look at, donor account + name is pretty safe
    if extra[:donor_account]
      if other_person = extra[:donor_account].people.where('people.first_name' => person.first_name,
                                                           'people.last_name' => person.last_name,
                                                           'people.suffix' => person.suffix)
                                                    .where('people.middle_name = ? OR people.middle_name is null', person.middle_name)
                                                    .first
        return other_person.master_person
      end

    end

    nil
  end

  def merge(other)
    People.where(master_person_id: other.id).update_all(master_person_id: id)
    MasterPersonSource.where(master_person_id: other.id).update_all(master_person_id: id)
    MasterPersonDonorAccount.where(master_person_id: other.id).update_all(master_person_id: id)
    other.reload
    other.destroy
  end
end
