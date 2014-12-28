require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  # The reason these are large queries and not Ruby code with loops is that as I introduced more duplicate
  # search options, that code got painfully slow and so I re-wrote the logic as self-join queries for performance.

  def dup_contact_sets
    sql = dup_contacts_sql.gsub(':account_list_id', Contact.connection.quote(@account_list.id))
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

  CREATE_TEMP_TABLES = "
    DROP TABLE IF EXISTS account_ppl;
    DROP TABLE IF EXISTS ppl_unsplit_names;
    DROP TABLE IF EXISTS ppl_names;
    DROP TABLE IF EXISTS dup_ppl_by_name;
    DROP TABLE IF EXISTS ppl_name_male_ratios;
    DROP TABLE IF EXISTS dup_ppl;

    SELECT people.id, first_name, legal_first_name, middle_name, last_name
    INTO TEMP account_ppl
    FROM people
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
    WHERE contacts.account_list_id = :account_list_id
      AND contacts.name not like '%nonymous%'
      AND people.first_name not like '%nknow%';

    CREATE INDEX ON account_ppl (id);

    SELECT *
    INTO TEMP ppl_unsplit_names
    FROM (
      SELECT first_name as name, 'first' as name_source, id, first_name, last_name FROM account_ppl
      UNION SELECT legal_first_name, 'first' as name_source, id, first_name, last_name FROM account_ppl
        WHERE legal_first_name is not null and legal_first_name <> ''
      UNION SELECT middle_name, 'middle' as name_source, id, first_name, last_name FROM account_ppl
        WHERE middle_name is not null and middle_name <> ''
    ) as people_unsplit_names_query;

    SELECT lower(name) as name, name_source, id, first_name, lower(last_name) as last_name
    INTO TEMP ppl_names
    FROM (
      SELECT replace(name, ' ', '') as name, name_source, id, first_name, last_name FROM ppl_unsplit_names
      UNION SELECT regexp_split_to_table(regexp_replace(name, '[\\.-]+$', ''), '([\\. -]+|$)+'),
        name_source, id, first_name, last_name
      FROM ppl_unsplit_names WHERE name ~ '[\\. -]'
      UNION SELECT regexp_split_to_table(regexp_replace(name, '(^[A-Z]|[a-z])([A-Z])', '\\1 \\2'), ' '),
        name_source, id, first_name, last_name
      FROM ppl_unsplit_names WHERE name ~ '(^[A-Z]|[a-z])([A-Z])' and name !~ '[A-Z]{3}'
    ) as people_names_query;

    CREATE INDEX ON ppl_names (id);
    CREATE INDEX ON ppl_names (name);
    CREATE INDEX ON ppl_names (last_name);

    SELECT ppl.id as person_id, dups.id as dup_person_id, nicknames.id as nickname_id,
      case
        when ppl.name = nicknames.nickname then 800
        when dups.name_source = 'middle' then 700
        when ppl.first_name ~ '^[A-Z][a-z]+[A-Z][a-z].*' then 600
        when ppl.first_name ~ '^[A-Z][A-Z]$|^[A-Z]\\.\s?[A-Z]\\.$' then 500
        when ppl.first_name ~ '^[A-Z][a-z]+ [A-Z][a-z]' then 400
        when dups.first_name ~ '([. ]|^)[A-Za-z]([. ]|$)' then 300
        when dups.first_name ~ '.*\\.' then 200
        when dups.id > ppl.id then 100
        else 50
      end as priority,
      (char_length(ppl.name) = 1 or char_length(dups.name) = 1
        or dups.name_source = 'middle' or ppl.name_source = 'middle'
      ) as check_genders
    INTO TEMP dup_ppl_by_name
    FROM ppl_names as ppl
      INNER JOIN ppl_names as dups ON ppl.id <> dups.id
      LEFT JOIN nicknames ON nicknames.suggest_duplicates = 't'
        and ((ppl.name = nicknames.nickname and dups.name = nicknames.name)
          or (ppl.name = nicknames.name and dups.name = nicknames.nickname))
    WHERE ppl.last_name = dups.last_name
      and (ppl.name_source = 'first' or dups.name_source = 'first')
      and (
        nicknames.id is not null
        or (dups.name = ppl.name and char_length(ppl.name) > 1)
        or ((char_length(dups.name) = 1 or char_length(ppl.name) = 1)
          and (dups.name = substring(ppl.name from 1 for 1) or ppl.name = substring(dups.name from 1 for 1))));


    SELECT *
    INTO TEMP dup_ppl
    FROM (
      SELECT dup_ppl_by_name.*, contact_people.contact_id
        FROM dup_ppl_by_name
        INNER JOIN contact_people ON contact_people.person_id = dup_ppl_by_name.person_id
        INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_ppl_by_name.dup_person_id
        WHERE contact_people.contact_id = dup_contact_people.contact_id
      UNION
      SELECT ppl.id as person_id, dups.id as dup_person_id,
        null as nickname_id,
        case when contacts.name ilike ppl.last_name || ',%' then 10
           when ppl.last_name is not null and ppl.last_name <> '' then 5
           when ppl.id < dups.id then 3 else 1
        end as priority,
        true as check_genders,
        contacts.id as contact_id
      FROM account_ppl as ppl
        INNER JOIN account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN email_addresses ON email_addresses.person_id = ppl.id
        INNER JOIN email_addresses as dup_email_addresses ON dup_email_addresses.person_id = dups.id
        INNER JOIN contact_people ON ppl.id = contact_people.person_id
        INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dups.id
        INNER JOIN contacts ON contact_people.contact_id = contacts.id
      WHERE contact_people.contact_id = dup_contact_people.contact_id
        and lower(email_addresses.email) = lower(dup_email_addresses.email)
      UNION
      SELECT ppl.id as person_id, dups.id as dup_person_id, null as nickname_id,
        case
          when contacts.name ilike ppl.last_name || ',%' then 10
          when ppl.last_name is not null and ppl.last_name <> '' then 5
          when ppl.id < dups.id then 3
          else 1
        end as priority,
        true as check_genders,
        contacts.id as contact_id
      FROM account_ppl as ppl
        INNER JOIN account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN phone_numbers ON phone_numbers.person_id = ppl.id
        INNER JOIN phone_numbers as dup_phone_numbers ON dup_phone_numbers.person_id = dups.id
        INNER JOIN contact_people ON ppl.id = contact_people.person_id
        INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dups.id
        INNER JOIN contacts ON contact_people.contact_id = contacts.id
      WHERE contact_people.contact_id = dup_contact_people.contact_id
        and phone_numbers.number = dup_phone_numbers.number
    ) AS dup_people_query;

    SELECT ppl_names.id, AVG(name_male_ratios.male_ratio) as male_ratio
    INTO TEMP ppl_name_male_ratios
    FROM ppl_names
    LEFT JOIN name_male_ratios ON ppl_names.name = name_male_ratios.name
    GROUP BY ppl_names.id;
  "

  DUP_PEOPLE_NEW_SQL = "
    SELECT person_id, dup_person_id, nickname_id, contact_id
    FROM dup_ppl
      INNER JOIN people ON dup_ppl.person_id = people.id
      INNER JOIN people AS dup_people ON dup_ppl.dup_person_id = dup_people.id
      INNER JOIN ppl_name_male_ratios name_male_ratios ON name_male_ratios.id = people.id
      INNER JOIN ppl_name_male_ratios dup_name_male_ratios ON dup_name_male_ratios.id = dup_people.id
      INNER JOIN contacts ON contacts.id = dup_ppl.contact_id
    WHERE contacts.name NOT ilike ('%' || people.first_name || '% and %' || dup_people.first_name || '%')
      and contacts.name NOT ilike ('%' || dup_people.first_name || '% and %' || people.first_name || '%')
      and (
        check_genders = 'f'
        or (
              (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
              AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
            OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
            OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9)))
    ORDER BY priority DESC;
    "

  def dup_people_rows
    #sql = dup_people_sql.gsub(':account_list_id', Contact.connection.quote(@account_list.id))
    statements = CREATE_TEMP_TABLES.gsub(':account_list_id', Contact.connection.quote(@account_list.id)).split(';')
    statements.each do |sql|
      Person.connection.exec_query(sql)
    end

    sql = DUP_PEOPLE_NEW_SQL
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

  def dup_contacts_sql
    "#{dup_contacts_by_name_sql}
        UNION #{dup_contacts_by_email_sql}
        UNION #{dup_contacts_by_phone_sql}
        UNION #{dup_contacts_by_address_sql}"
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

  def dup_contacts_where
    "contacts.account_list_id = :account_list_id AND dup_contacts.account_list_id = :account_list_id
    AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'"
  end

  def dup_common_where
    "#{dup_contacts_where}
    AND people.first_name not like '%nknow%' AND dup_people.first_name not like '%nknow%'"
  end

  def dup_people_where
    "#{dup_common_where}
    AND contacts.name NOT ilike ('%' || people.first_name || '% and %' || dup_people.first_name || '%')
    AND contacts.name NOT ilike ('%' || dup_people.first_name || '% and %' || people.first_name || '%')"
  end

  def people_combined_name_fields
    sql = '('
    [
      { field: 'first_name', source: 'first' },  { field: 'legal_first_name', source: 'first' }, { field: 'middle_name', source: 'middle' }
    ].each_with_index do |field_info, index|
      sql +=  ' UNION ' if index > 0
      sql += "SELECT #{field_info[:field]} as name_multi_field, '#{field_info[:source]}' as name_source, * FROM people\n"
    end
    sql + ') as people'
  end

  def people_expanded_names(all_fields)
    table = all_fields ? people_combined_name_fields : 'people'
    name_field = all_fields ? 'name_multi_field' : 'first_name'

    sql = '('
    [
      # Split names like "Mary Beth", "Mary-Beth", "M Beth", "M.B." into multiple rows by period, space and dash.
      # If the regexp doesn't match, it just returns the whole name
      # The regexp_replace inside is to get rid of a "." or "-" at the end of the name and so prevent empty name_part entries
      { name_part: "regexp_split_to_table(regexp_replace(#{name_field}, '[\\.-]+$', ''), '([\\. -]+|$)+')",
        where: '' },

      # Split names like "MaryBeth" or "JW". Only do a single replacement (by default regexp_replace isn't global),
      # because we don't want to split apart organization acronyms like "CCC NEHQ" or "Somewhereville UMC"
      { name_part: "regexp_split_to_table(regexp_replace(#{name_field}, '(^[A-Z]|[a-z])([A-Z])', '\\1 \\2'), ' ')",
        where: " WHERE #{name_field} !~ '[A-Z]{3}'" },

      # Try removing the spaces in a name, to match examples like "Marybeth" and "Mary Beth"
      { name_part: "replace(#{name_field}, ' ', '')", where: '' }
    ].each_with_index do |split_info, index|
      sql +=  ' UNION ' if index > 0
      sql += "SELECT #{split_info[:name_part]} as name_part, * FROM #{table}#{split_info[:where]}\n"
    end
    sql + ')'
  end

  def people_name_male_ratios
    "
    (
      SELECT people.id, AVG(name_male_ratios.male_ratio) as male_ratio
      FROM #{people_expanded_names(false)} as people
      LEFT JOIN name_male_ratios ON lower(people.name_part) = name_male_ratios.name
      GROUP BY people.id
    )"
  end

  def dup_contacts_by_name_sql
    "
    SELECT contacts.id as contact_id, dup_contacts.id as dup_contact_id
    FROM #{people_expanded_names(false)} as people
      INNER JOIN #{people_expanded_names(false)} as dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} as name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} as dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
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
      INNER JOIN email_addresses as dup_email_addresses
        ON dup_email_addresses.person_id <> people.id
          AND lower(dup_email_addresses.email) = lower(email_addresses.email)
      INNER JOIN people as dup_people ON dup_people.id = dup_email_addresses.person_id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    WHERE #{dup_common_where}
      AND contacts.id < dup_contacts.id"
  end

  def dup_contacts_by_phone_sql
    "
    SELECT contacts.id, dup_contacts.id
    FROM people
      INNER JOIN phone_numbers ON phone_numbers.person_id = people.id
      INNER JOIN phone_numbers as dup_phone_numbers
        ON dup_phone_numbers.person_id <> people.id
          AND dup_phone_numbers.number = phone_numbers.number
      INNER JOIN people as dup_people ON dup_people.id = dup_phone_numbers.person_id
      INNER JOIN contact_people ON contact_people.person_id = people.id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
    WHERE #{dup_common_where}
      AND contacts.id < dup_contacts.id"
  end

  def dup_contacts_by_address_sql
    "
    SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN contacts as dup_contacts ON contacts.id < dup_contacts.id
      INNER JOIN addresses
        ON addresses.addressable_type = 'Contact' AND addresses.addressable_id = contacts.id
      INNER JOIN addresses as dup_addresses
        ON dup_addresses.addressable_type = 'Contact' AND dup_addresses.addressable_id = dup_contacts.id
    WHERE #{dup_contacts_where}
      AND addresses.primary_mailing_address = 't'
      AND dup_addresses.primary_mailing_address = 't'
      AND addresses.master_address_id = dup_addresses.master_address_id"
  end

  def dup_people_by_name_sql
    "
    SELECT people.id as person_id, dup_people.id as dup_person_id, contacts.id as contact_id,
      nicknames.id as nickname_id,
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
    FROM #{people_expanded_names(true)} as people
      INNER JOIN #{people_expanded_names(true)} as dup_people ON people.id <> dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      LEFT JOIN nicknames ON nicknames.suggest_duplicates = 't'
        AND (
          (lower(people.name_part) = nicknames.nickname AND lower(dup_people.name_part) = nicknames.name)
          OR
          (lower(people.name_part) = nicknames.name AND lower(dup_people.name_part) = nicknames.nickname)
        )
      INNER JOIN #{people_name_male_ratios} as name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} as dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
    WHERE #{dup_people_where}
      AND contacts.id = dup_contacts.id
      AND lower(people.last_name) = lower(dup_people.last_name)
      AND (people.name_source = 'first' OR dup_people.name_source = 'first')
      AND (
        (lower(dup_people.name_part) = lower(people.name_part) AND char_length(people.name_part) > 1)
        OR nicknames.id is not null
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
    SELECT people.id as person_id, dup_people.id as dup_person_id, contacts.id as contact_id,
      NULL as nickname_id,
      CASE
        WHEN contacts.name ILIKE people.last_name || ',%' THEN 10
        WHEN people.last_name is not null AND people.last_name <> '' THEN 5
        WHEN people.id < dup_people.id THEN 3
        ELSE 1
      END as priority
    FROM people
      INNER JOIN people as dup_people ON people.id <> dup_people.id
      INNER JOIN email_addresses ON email_addresses.person_id = people.id
      INNER JOIN email_addresses as dup_email_addresses ON dup_email_addresses.person_id = dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} as name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} as dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
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
    SELECT people.id as person_id, dup_people.id as dup_person_id, contacts.id as contact_id,
      NULL as nickname_id,
      CASE
        WHEN contacts.name ILIKE people.last_name || ',%' THEN 10
        WHEN people.last_name is not null AND people.last_name <> '' THEN 5
        WHEN people.id < dup_people.id THEN 3
        ELSE 1
      END as priority
    FROM people
      INNER JOIN people as dup_people ON people.id <> dup_people.id
      INNER JOIN phone_numbers ON phone_numbers.person_id = people.id
      INNER JOIN phone_numbers as dup_phone_numbers ON dup_phone_numbers.person_id = dup_people.id
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_people.id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
      INNER JOIN contacts as dup_contacts ON dup_contacts.id = dup_contact_people.contact_id
      INNER JOIN #{people_name_male_ratios} as name_male_ratios ON people.id = name_male_ratios.id
      INNER JOIN #{people_name_male_ratios} as dup_name_male_ratios ON dup_people.id = dup_name_male_ratios.id
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
end
