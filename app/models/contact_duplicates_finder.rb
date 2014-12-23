require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  def dup_people_sets
    # Only return duplicated people if they are in the same contact. If they're in different contacts, the user should consider
    # merging the whole contacts first, then they can merge the duplicated people within them (and those with the
    # same name would be automatically merged anyway).
    people_sets = dup_people_by_nickname_cached.select { |dup| dup.shared_contact.present? }

    # Update the number of times we offer a nickname to the user so we can track which ones are most useful
    Nickname.update_counters(people_sets.map(&:nickname_id), num_times_offered: 1)

    people_sets.sort_by! { |s| s.shared_contact.name }
  end

  def dup_people_by_same_name
    # Find sets of people with the same name
    sql = "SELECT array_to_string(array_agg(people.id), ',')
               FROM people
               INNER JOIN contact_people ON people.id = contact_people.person_id
               INNER JOIN contacts ON contact_people.contact_id = contacts.id
               WHERE contacts.account_list_id = :account_list_id
               AND name not like '%nonymous%'
               AND first_name not like '%nknow%'
               GROUP BY first_name, last_name
               HAVING count(*) > 1"
    Person.connection.select_values(sql).map { |dup_person_ids| dup_person_ids.split(',').map(&:to_i) }
  end

  def dup_people_by_email
    sql = "SELECT array_to_string(array_agg(email_addresses.person_id), ',')
               FROM email_addresses
               INNER JOIN people ON email_addresses.person_id = people.id
               INNER JOIN contact_people ON contact_people.person_id = people.id
               INNER JOIN contacts ON contact_people.contact_id = contacts.id
               WHERE contacts.account_list_id = :account_list_id
               AND name not like '%nonymous%'
               AND first_name not like '%nknow%'
               GROUP BY email
               HAVING count(*) > 1"
    Person.connection.select_values(sql).map { |dup_person_ids| dup_person_ids.split(',').map(&:to_i) }
  end

  def dup_people_by_phone
    sql = "SELECT array_to_string(array_agg(phone_numbers.person_id), ',')
               FROM phone_numbers
               INNER JOIN people ON phone_numbers.person_id = people.id
               INNER JOIN contact_people ON contact_people.person_id = people.id
               INNER JOIN contacts ON contact_people.contact_id = contacts.id
               WHERE contacts.account_list_id = :account_list_id
               AND name not like '%nonymous%'
               AND first_name not like '%nknow%'
               GROUP BY number
               HAVING count(*) > 1"
    Person.connection.select_values(sql).map { |dup_person_ids| dup_person_ids.split(',').map(&:to_i) }
  end

  # Cache it in this instance so that both dup_contact_sets and dup_people_sets (both called by the same
  # controller method) can share the query results.
  def dup_people_by_nickname_cached
    @dup_people_by_nickname ||= dup_people_by_nickname
  end

  def dup_people_by_nickname
    dups = dup_people_by_nickname_query.map do |dup|
      OpenStruct.new(person: Person.find(dup.person_id), dup_person: Person.find(dup.dup_person_id),
                     shared_contact: dup.shared_contact_id ? Contact.find(dup.shared_contact_id) : nil,
                     nickname_id: dup.nickname_id)
    end
    dups.reject { |dup| dup.person.not_same_as?(dup.dup_person) }
  end

  def dup_people_by_nickname_query
    @account_list.people
      .select('people.id as person_id, people_dups.id AS dup_person_id, nicknames.id AS nickname_id, '\
        'MIN(CASE WHEN contact_people.contact_id = contact_people_dups.contact_id '\
          'THEN contact_people.contact_id ELSE NULL END) AS shared_contact_id')
      .joins('INNER JOIN nicknames ON LOWER(people.first_name) = nicknames.nickname')
      .joins('INNER JOIN people AS people_dups ON LOWER(people_dups.first_name) = nicknames.name')
      .joins('INNER JOIN contact_people AS contact_people_dups ON contact_people_dups.person_id = people_dups.id')
      .joins('INNER JOIN contacts AS contact_dups ON contact_dups.id = contact_people_dups.contact_id')
      .where("nicknames.suggest_duplicates = 'true'")
      .where('people.last_name = people_dups.last_name')
      .where('contact_dups.account_list_id = ?', @account_list.id)
      .group('people.id, dup_person_id, nickname_id')
  end

  # The reason this is a large query and not Ruby code with loops is that as I introduced more duplicate
  # search options, that code got painfully slow and so I pull it into a single query. The reason for multiple different
  # queries for different sorts of searches was that when I tried to combine them into a single query they weren't
  # efficient. I believe the separate queries are easier for Postgres to digest and optimize.
  def dup_contact_sets
    sql = "#{DUP_CONTACTS_BY_NAMES_SQL}
        UNION #{DUP_CONTACTS_BY_EMAILS_SQL}
        UNION #{DUP_CONTACTS_BY_PHONE_SQL}
        UNION #{DUP_CONTACTS_BY_ADDRESS_SQL}"
    sql.gsub!(':account_list_id', Contact.connection.quote(@account_list.id))
    contact_id_pairs = Contact.connection.exec_query(sql).rows

    contacts = Contact.select(:id, :name, :not_duplicated_with).where(id: contact_id_pairs.flatten.uniq)
    contact_by_id = Hash[contacts.map { |contact| [contact.id, contact] }]
    contact_sets = contact_id_pairs.map { |pair| [contact_by_id[pair.first.to_i], contact_by_id[pair.second.to_i]] }
    contact_sets.reject { |pair| pair.first.not_same_as?(pair.second) }
  end

  DUP_CONTACTS_BY_NAMES_SQL =
    "SELECT contacts.id, dup_contacts.id
    FROM people
      INNER JOIN people AS dup_people ON people.id < dup_people.id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    LEFT JOIN nicknames
      ON LOWER(people.first_name) = nicknames.nickname AND LOWER(dup_people.first_name) = nicknames.name
    WHERE contacts.account_list_id = :account_list_id
      AND dup_contacts.account_list_id = :account_list_id
      AND contacts.id < dup_contacts.id
      AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
      AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'
      AND LOWER(dup_people.last_name) = LOWER(people.last_name)
      AND (LOWER(dup_people.first_name) = LOWER(people.first_name) OR nicknames.id IS NOT NULL)"

  DUP_CONTACTS_BY_EMAILS_SQL =
    "SELECT contacts.id, dup_contacts.id
    FROM people
      INNER JOIN email_addresses ON email_addresses.person_id = people.id
      INNER JOIN email_addresses AS dup_email_addresses
        ON dup_email_addresses.person_id <> people.id
          AND LOWER(dup_email_addresses.email) = LOWER(email_addresses.email)
      INNER JOIN people AS dup_people ON dup_people.id = dup_email_addresses.person_id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    WHERE contacts.account_list_id = :account_list_id
      AND dup_contacts.account_list_id = :account_list_id
      AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
      AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'
      AND contacts.id < dup_contacts.id"

  DUP_CONTACTS_BY_PHONE_SQL =
    "SELECT contacts.id, dup_contacts.id
    FROM people
      INNER JOIN phone_numbers ON phone_numbers.person_id = people.id
      INNER JOIN phone_numbers AS dup_phone_numbers
        ON dup_phone_numbers.person_id <> people.id
          AND dup_phone_numbers.number = phone_numbers.number
      INNER JOIN people AS dup_people ON dup_people.id = dup_phone_numbers.person_id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    WHERE contacts.account_list_id = :account_list_id
      AND dup_contacts.account_list_id = :account_list_id
      AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
      AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'
      AND contacts.id < dup_contacts.id"

  DUP_CONTACTS_BY_ADDRESS_SQL =
    "SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN addresses ON addresses.addressable_type = 'Contact' AND addresses.addressable_id = contacts.id
      INNER JOIN addresses AS dup_addresses
        ON dup_addresses.addressable_type = 'Contact' AND addresses.addressable_id < dup_addresses.addressable_id
          AND addresses.master_address_id = dup_addresses.master_address_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_addresses.addressable_id
    WHERE contacts.account_list_id = :account_list_id
      AND dup_contacts.account_list_id = :account_list_id
      AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
      AND addresses.primary_mailing_address = 't'
      AND dup_addresses.primary_mailing_address = 't'"
end
