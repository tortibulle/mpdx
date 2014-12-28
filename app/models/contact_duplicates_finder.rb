require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  # The reason these are large queries and not Ruby code with loops is that as I introduced more duplicate
  # search options, that code got painfully slow and so I re-wrote the logic as self-join queries for performance.

  def dup_contact_sets
    sql = "#{dup_contacts_by_name_sql}
        UNION #{dup_contacts_by_email_sql}
        UNION #{dup_contacts_by_phone_sql}
        UNION #{dup_contacts_by_address_sql}"
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

  private

  def dup_people_rows
    sql = dup_people_sql.gsub(':account_list_id', Contact.connection.quote(@account_list.id))
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

  def dup_contacts_where
    "
    contacts.account_list_id = :account_list_id
    AND dup_contacts.account_list_id = :account_list_id
    AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
    "
  end

  def dup_common_where
    "
    #{dup_contacts_where}
    AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'"
  end

  def dup_people_where
    "
    #{dup_common_where}
    AND contacts.name NOT ilike ('%' || people.first_name || '% and %' || dup_people.first_name || '%')
    AND contacts.name NOT ilike ('%' || dup_people.first_name || '% and %' || people.first_name || '%')"
  end

  def people_combined_name_fields
    "
    (
      SELECT first_name AS name_part, id, first_name, last_name, gender, 'first' as name_source FROM people
      UNION SELECT legal_first_name, id, first_name,last_name, gender, 'first' as name_source FROM people
      UNION SELECT middle_name, id, first_name,last_name, gender, 'middle' as name_source FROM people
    ) AS people"
  end

  def people_expanded_names
    "
    (
      SELECT first_name AS name_part, id, first_name, last_name, gender FROM people
      UNION SELECT regexp_split_to_table(regexp_replace(first_name, '[\\. -]+$', ''), '([\\. -]+|$)+'), id, first_name, last_name, gender
        FROM people WHERE first_name ~ '.*[\\. -].*'
      UNION SELECT regexp_split_to_table(regexp_replace(first_name, '([A-Za-z])([A-Z])', '\\1 \\2'), ' '), id, first_name, last_name, gender
        FROM people WHERE first_name ~ '^[A-Za-z][A-Z]' AND first_name !~ '^[A-Z]{3}'
      UNION SELECT replace(people.first_name, ' ', ''), id, first_name, last_name, gender FROM people WHERE first_name ~ ' '
    )"
  end

  def people_expanded_names_all_fields
    "
    (
      SELECT name_part, id, first_name, last_name, gender, name_source FROM
      (
          SELECT name_part AS name_part, id, first_name, last_name, gender, name_source
          FROM #{people_combined_name_fields}
        UNION
          SELECT regexp_split_to_table(name_part, '[. -]'), id, first_name, last_name, gender, name_source
          FROM #{people_combined_name_fields}
          WHERE name_part SIMILAR TO '%[. -]%'
        UNION
          SELECT regexp_split_to_table(regexp_replace(name_part, '([A-Z])([A-Z])', ' \\1 \\2'), ' '), id, first_name, last_name, gender, name_source
          FROM #{people_combined_name_fields}
          WHERE name_part SIMILAR TO '[A-Z]{2}%' AND name_part NOT SIMILAR TO '%[A-Z]{3}%'
        UNION
          SELECT regexp_split_to_table(regexp_replace(name_part, '([a-z])([A-Z])', '\\1 \\2'), ' '), id, first_name, last_name, gender, name_source
          FROM #{people_combined_name_fields}
          WHERE name_part SIMILAR TO '%[a-z][A-Z]%'
        UNION
          SELECT replace(people.name_part, ' ', ''), id, first_name, last_name, gender, name_source
          FROM #{people_combined_name_fields}
          WHERE name_part LIKE '% %'
      ) AS expanded_names_with_blanks
      WHERE name_part IS NOT NULL AND name_part <> ''
    )"
  end

  def people_name_male_ratios
    "
    (
      SELECT people.id, AVG(name_male_ratios.male_ratio) AS male_ratio
      FROM #{people_expanded_names} AS people
      LEFT JOIN name_male_ratios ON lower(people.name_part) = name_male_ratios.name
      GROUP BY people.id
    )"
  end

  def dup_contacts_by_name_sql
    "
    SELECT contacts.id AS contact_id, dup_contacts.id AS dup_contact_id
    FROM #{people_expanded_names} AS people
      INNER JOIN #{people_expanded_names} AS dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} AS name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} AS dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
      LEFT JOIN nicknames
        ON nicknames.suggest_duplicates = 't' AND lower(people.name_part) = nicknames.nickname
    WHERE #{dup_common_where}
      AND lower(dup_people.last_name) = lower(people.last_name)
      AND contacts.id <> dup_contacts.id
      AND (
        (
            lower(dup_people.name_part) = lower(people.name_part)
            AND char_length(people.name_part) > 1
            AND contacts.id < dup_contacts.id
        )
        OR lower(dup_people.name_part) = nicknames.name
        OR (
          char_length(dup_people.name_part) = 1
          AND lower(dup_people.name_part) = lower(substring(people.name_part from 1 for 1))
          AND (
            name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL
            OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
            OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)
          )
        )
      )"
  end

  def dup_contacts_by_email_sql
    "
    SELECT contacts.id, dup_contacts.id
    FROM people
      INNER JOIN email_addresses ON email_addresses.person_id = people.id
      INNER JOIN email_addresses AS dup_email_addresses
        ON dup_email_addresses.person_id <> people.id
          AND lower(dup_email_addresses.email) = lower(email_addresses.email)
      INNER JOIN people AS dup_people ON dup_people.id = dup_email_addresses.person_id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    WHERE #{dup_common_where}
      AND contacts.id < dup_contacts.id"
  end

  def dup_contacts_by_phone_sql
    "
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
    WHERE #{dup_common_where}
      AND contacts.id < dup_contacts.id"
  end

  def dup_contacts_by_address_sql
    "
    SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN contacts AS dup_contacts ON contacts.id < dup_contacts.id
      INNER JOIN addresses
        ON addresses.addressable_type = 'Contact' AND addresses.addressable_id = contacts.id
      INNER JOIN addresses AS dup_addresses
        ON dup_addresses.addressable_type = 'Contact' AND dup_addresses.addressable_id = dup_contacts.id
    WHERE #{dup_contacts_where}
      AND addresses.primary_mailing_address = 't'
      AND dup_addresses.primary_mailing_address = 't'
      AND addresses.master_address_id = dup_addresses.master_address_id"
  end

  def dup_people_by_name_sql
    "
    SELECT people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id,
      nicknames.id AS nickname_id,
      CASE
        WHEN LOWER(people.name_part) = nicknames.nickname THEN 800
        WHEN dup_people.name_source = 'middle' THEN 700
        WHEN people.first_name ~ '^[A-Z][a-z]+[A-Z][a-z].*' THEN 600
        WHEN people.first_name ~ '^[A-Z][A-Z]$|^[A-Z]\\.\s?[A-Z]\\.$' THEN 500
        WHEN people.first_name ~ '^[A-Z][a-z]+ [A-Z][a-z]' THEN 400
        WHEN dup_people.first_name ~ '([. ]|^)[A-Za-z]([. ]|$)' THEN 300
        WHEN dup_people.first_name ~ '.*\\.' THEN 200
        WHEN dup_people.id > people.id THEN 100
        ELSE 50
      END as priority
    FROM #{people_expanded_names_all_fields} AS people
      INNER JOIN #{people_expanded_names_all_fields} AS dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      LEFT JOIN nicknames ON nicknames.suggest_duplicates = 't'
        AND (
          (lower(people.name_part) = nicknames.nickname AND lower(dup_people.name_part) = nicknames.name)
          OR
          (lower(people.name_part) = nicknames.name AND lower(dup_people.name_part) = nicknames.nickname)
        )
      INNER JOIN #{people_name_male_ratios} AS name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} AS dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
    WHERE #{dup_people_where}
      AND contacts.id = dup_contacts.id
      AND lower(people.last_name) = lower(dup_people.last_name)
      AND (people.name_source = 'first' OR dup_people.name_source = 'first')
      AND (
        (lower(dup_people.name_part) = lower(people.name_part) AND char_length(people.name_part) > 1)
        OR nicknames.id IS NOT NULL
        OR (
            (char_length(dup_people.name_part) = 1 OR char_length(people.name_part) = 1)
          AND
            (
              lower(dup_people.name_part) = lower(substring(people.name_part from 1 for 1))
              OR
              lower(people.name_part) = lower(substring(dup_people.name_part from 1 for 1))
            )
          AND (
            (
              (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
              AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
            )
            OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
            OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)
          )
        )
      )
      AND (
        (dup_people.name_source = 'first' AND people.name_source = 'first')
        OR
        (
          (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
          AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
        )
        OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
        OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)
      )
      "
  end

  # This was split into an inner and outer query because joining to name_male_ratios inside the query was super slow
  def dup_people_by_email_sql
    "
    SELECT people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id,
      NULL AS nickname_id,
      CASE
        WHEN contacts.name ILIKE people.last_name || ',%' THEN 10
        WHEN people.last_name IS NOT NULL AND people.last_name <> '' THEN 5
        WHEN people.id < dup_people.id THEN 3
        ELSE 1
      END as priority
    FROM people
      INNER JOIN people AS dup_people ON people.id <> dup_people.id
      INNER JOIN email_addresses ON email_addresses.person_id = people.id
      INNER JOIN email_addresses AS dup_email_addresses ON dup_email_addresses.person_id = dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} AS name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} AS dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
    WHERE #{dup_people_where}
      AND contacts.id = dup_contacts.id
      AND lower(email_addresses.email) = lower(dup_email_addresses.email)
      AND (
        (
          (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
          AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
        )
        OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
        OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)
      )"
  end

  # This was split into an inner and outer query because joining to name_male_ratios inside the query was super slow
  def dup_people_by_phone_sql
    "
    SELECT people.id as person_id, dup_people.id AS dup_person_id, contacts.id AS contact_id,
      NULL AS nickname_id,
      CASE
        WHEN contacts.name ILIKE people.last_name || ',%' THEN 10
        WHEN people.last_name IS NOT NULL AND people.last_name <> '' THEN 5
        WHEN people.id < dup_people.id THEN 3
        ELSE 1
      END as priority
    FROM people
      INNER JOIN people AS dup_people ON people.id <> dup_people.id
      INNER JOIN phone_numbers ON phone_numbers.person_id = people.id
      INNER JOIN phone_numbers AS dup_phone_numbers ON dup_phone_numbers.person_id = dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people AS dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts AS dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} AS name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} AS dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
    WHERE #{dup_people_where}
      AND contacts.id = dup_contacts.id
      AND phone_numbers.number = dup_phone_numbers.number
      AND (
        (
          (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
          AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
        )
        OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
        OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)
      )"
  end

  # Order by the nickname_id to get the duplicate with nicknames first since we want to preserve their ordering
  # to make the default merge prefer the nickname person
  def dup_people_sql
    "
      #{dup_people_by_name_sql}
      UNION
      #{dup_people_by_email_sql}
      UNION
      #{dup_people_by_phone_sql}
      ORDER BY priority DESC, nickname_id"
  end
end
