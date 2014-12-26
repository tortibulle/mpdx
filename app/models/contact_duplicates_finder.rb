require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  # The reason these are large queries and not Ruby code with loops is that as I introduced more duplicate
  # search options, that code got painfully slow and so I re-wrote the logic as self-join queries for performance.

  def dup_contact_sets
    sql = "#{DUP_CONTACTS_BY_NAME_SQL}
        UNION #{DUP_CONTACTS_BY_EMAILS_SQL}
        UNION #{DUP_CONTACTS_BY_PHONE_SQL}
        UNION #{DUP_CONTACTS_BY_ADDRESS_SQL}"
    sql.gsub!(':account_list_id', Contact.connection.quote(@account_list.id))
    contact_id_pairs = Contact.connection.exec_query(sql).rows

    dup_pairs_so_far = Set.new
    contact_id_pairs.reject! do |row|
      dup_set = row.sort
      already_included = dup_pairs_so_far.include?(dup_set)
      dup_pairs_so_far << dup_set
      already_included
    end

    contact_by_id = Hash[Contact.find(contact_id_pairs.flatten.uniq).map { |c| [c.id, c] }]

    contact_sets = contact_id_pairs.map { |pair| [contact_by_id[pair.first.to_i], contact_by_id[pair.second.to_i]] }
    contact_sets.reject { |pair| pair.first.not_same_as?(pair.second) }.sort_by { |pair| pair.first.name }
  end

  DUP_CONTACTS_WHERE = "
    contacts.account_list_id = :account_list_id
    AND dup_contacts.account_list_id = :account_list_id
    AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'"

  DUPS_COMMON_WHERE = "
    #{DUP_CONTACTS_WHERE}
    AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'"

  PEOPLE_EXPANDED_NAMES = "
    (
      SELECT * FROM
      (
        SELECT first_name, id, last_name, gender
        FROM people
        WHERE first_name NOT SIMILAR TO '%[\\. -]%'

        UNION

        SELECT regexp_split_to_table(first_name, '[\\. -]'), id, last_name, gender
        FROM people
        WHERE first_name SIMILAR TO '%[\\. -]%'

        UNION

        SELECT regexp_split_to_table(regexp_replace(first_name, '([A-Z])', '\1 '), ' '), id, last_name, gender
        FROM people
        WHERE first_name SIMILAR TO '%[A-Z]{2}%'
      ) AS expanded_names_with_blanks
      WHERE first_name IS NOT NULL AND first_name <> ''
    )"

  DUP_CONTACTS_BY_NAME_SQL = "
    SELECT contacts.id, dup_contacts.id
    FROM #{PEOPLE_EXPANDED_NAMES} AS people
      INNER JOIN #{PEOPLE_EXPANDED_NAMES} AS dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      LEFT JOIN nicknames
        ON nicknames.suggest_duplicates = 't' AND LOWER(people.first_name) = nicknames.nickname
    WHERE #{DUPS_COMMON_WHERE}
      AND LOWER(dup_people.last_name) = LOWER(people.last_name)
      AND contacts.id <> dup_contacts.id
      AND (
        (LOWER(dup_people.first_name) = LOWER(people.first_name) AND contacts.id < dup_contacts.id)
        OR LOWER(dup_people.first_name) = nicknames.name
        OR (
          char_length(dup_people.first_name) = 1
          AND LOWER(dup_people.first_name) = LOWER(substring(people.first_name from 1 for 1))
        )
      )"

  DUP_CONTACTS_BY_EMAILS_SQL = "
    SELECT contacts.id, dup_contacts.id
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
    WHERE #{DUPS_COMMON_WHERE}
      AND contacts.id < dup_contacts.id"

  DUP_CONTACTS_BY_PHONE_SQL = "
    SELECT contacts.id, dup_contacts.id
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
    WHERE #{DUPS_COMMON_WHERE}
      AND contacts.id < dup_contacts.id"

  DUP_CONTACTS_BY_ADDRESS_SQL = "
    SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN contacts AS dup_contacts ON contacts.id < dup_contacts.id
      INNER JOIN addresses
        ON addresses.addressable_type = 'Contact' AND addresses.addressable_id = contacts.id
      INNER JOIN addresses AS dup_addresses
        ON dup_addresses.addressable_type = 'Contact' AND dup_addresses.addressable_id = dup_contacts.id
    WHERE #{DUP_CONTACTS_WHERE}
      AND addresses.primary_mailing_address = 't'
      AND dup_addresses.primary_mailing_address = 't'
      AND addresses.master_address_id = dup_addresses.master_address_id"

  def dup_people_sets
    dup_rows = dup_people_rows

    # Update the nickname times offered counter to track which nicknames end up being useful
    Nickname.update_counters(dup_rows.map { |r| r[:nickname_id] }.compact, num_times_offered: 1)

    contact_by_id = Hash[Contact.find(dup_rows.map { |r| r[:contact_id] }.uniq).map { |contact| [contact.id, contact] }]

    people = Person.find(dup_rows.map { |r| [r[:person_id], r[:dup_person_id]] }.flatten.uniq)
    person_by_id = Hash[people.map { |person| [person.id, person] }]

    people_sets = dup_rows.map do |row|
      OpenStruct.new(person: person_by_id[row[:person_id].to_i], dup_person: person_by_id[row[:dup_person_id].to_i],
                     shared_contact: contact_by_id[row[:contact_id].to_i])
    end

    people_sets.reject { |dup| dup.person.not_same_as?(dup.dup_person) }.sort_by! { |dup| dup.shared_contact.name }
  end

  def dup_people_rows
    # Order by the nickname_id to get the duplicate with nicknames first since we want to preserve their ordering
    # to make the default merge prefer the nickname person
    sql = "#{DUP_PEOPLE_BY_NAME_SQL}
      UNION #{DUP_PEOPLE_BY_EMAIL_SQL}
      UNION #{DUP_PEOPLE_BY_PHONE_SQL}
      ORDER BY nickname_id"
    sql.gsub!(':account_list_id', Contact.connection.quote(@account_list.id))
    dup_rows = Person.connection.exec_query(sql).to_hash.map(&:symbolize_keys)

    # Eliminate duplicates but keep the rows which are first
    dup_pairs_so_far = Set.new
    dup_rows.reject do |row|
      dup_set = [row[:person_id], row[:dup_person_id]].sort
      already_included = dup_pairs_so_far.include?(dup_set)
      dup_pairs_so_far << dup_set
      already_included
    end
  end

  DUP_PEOPLE_BY_NAME_SQL = "
    SELECT people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id, nicknames.id AS nickname_id
    FROM #{PEOPLE_EXPANDED_NAMES} AS people
      INNER JOIN #{PEOPLE_EXPANDED_NAMES} AS dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      LEFT JOIN nicknames ON nicknames.suggest_duplicates = 't' AND LOWER(people.first_name) = nicknames.nickname
    WHERE #{DUPS_COMMON_WHERE}
      AND contacts.id = dup_contacts.id
      AND LOWER(people.last_name) = LOWER(dup_people.last_name)
     AND (
        (LOWER(dup_people.first_name) = LOWER(people.first_name) AND people.id < dup_people.id)
        OR LOWER(dup_people.first_name) = nicknames.name
        OR (
          char_length(dup_people.first_name) = 1
          AND LOWER(dup_people.first_name) = LOWER(substring(people.first_name from 1 for 1))
        )
      )"

  # This was split into an inner and outer query because joining to name_male_ratios inside the query was super slow
  DUP_PEOPLE_BY_EMAIL_SQL = "
    SELECT person_id, dup_person_id, contact_id, nickname_id FROM
      (
        SELECT people.first_name, dup_people.first_name AS dup_first_name,
          people.gender, dup_people.gender AS dup_gender,
          people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id, NULL AS nickname_id
        FROM people
          INNER JOIN people AS dup_people ON people.id < dup_people.id
          INNER JOIN email_addresses ON email_addresses.person_id = people.id
          INNER JOIN email_addresses AS dup_email_addresses ON dup_email_addresses.person_id = dup_people.id
          INNER JOIN contact_people ON people.id = contact_people.person_id
          INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
          INNER JOIN contacts ON contact_people.contact_id = contacts.id
          INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
        WHERE #{DUPS_COMMON_WHERE}
          AND LOWER(email_addresses.email) = LOWER(dup_email_addresses.email)
      ) AS all_dups
    LEFT JOIN name_male_ratios
      ON LOWER(all_dups.first_name) = name_male_ratios.name
    LEFT JOIN name_male_ratios AS dup_name_male_ratios
      ON LOWER(all_dups.dup_first_name) = dup_name_male_ratios.name
    WHERE
      (
        (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
        AND (gender = dup_gender OR gender IS NULL OR dup_gender IS NULL)
      )
      OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
      OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)"

  # This was split into an inner and outer query because joining to name_male_ratios inside the query was super slow
  DUP_PEOPLE_BY_PHONE_SQL = "
    SELECT person_id, dup_person_id, contact_id, nickname_id FROM
      (
        SELECT people.first_name, dup_people.first_name AS dup_first_name,
          people.gender, dup_people.gender AS dup_gender,
          people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id, NULL AS nickname_id
        FROM people
          INNER JOIN people AS dup_people ON people.id < dup_people.id
          INNER JOIN phone_numbers ON phone_numbers.person_id = people.id
          INNER JOIN phone_numbers AS dup_phone_numbers ON dup_phone_numbers.person_id = dup_people.id
          INNER JOIN contact_people ON people.id = contact_people.person_id
          INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
          INNER JOIN contacts ON contact_people.contact_id = contacts.id
          INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
        WHERE #{DUPS_COMMON_WHERE}
          AND phone_numbers.number = dup_phone_numbers.number
      ) AS all_dups
      LEFT JOIN name_male_ratios
        ON LOWER(all_dups.first_name) = name_male_ratios.name
      LEFT JOIN name_male_ratios AS dup_name_male_ratios
        ON LOWER(all_dups.dup_first_name) = dup_name_male_ratios.name
      WHERE
        (
          (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
          AND (gender = dup_gender OR gender IS NULL OR dup_gender IS NULL)
        )
        OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
        OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)"
end
