require 'ostruct'

class ContactDuplicatesFinder
  CREATE_TEMP_TABLES = "
    DROP TABLE IF EXISTS account_ppl;
    DROP TABLE IF EXISTS ppl_unsplit_names;
    DROP TABLE IF EXISTS ppl_names;
    DROP TABLE IF EXISTS dup_ppl_by_name;
    DROP TABLE IF EXISTS dup_ppl_by_contact_info;
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
      ) as check_genders,
      ppl.name_source, dups.name_source as dup_name_source
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

    CREATE INDEX ON dup_ppl_by_name (person_id);
    CREATE INDEX ON dup_ppl_by_name (dup_person_id);

    SELECT *, true as check_genders
    INTO TEMP dup_ppl_by_contact_info
    FROM (
      SELECT ppl.id as person_id, dups.id as dup_person_id
      FROM account_ppl as ppl
        INNER JOIN account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN email_addresses ON email_addresses.person_id = ppl.id
        INNER JOIN email_addresses as dup_email_addresses ON dup_email_addresses.person_id = dups.id
      WHERE lower(email_addresses.email) = lower(dup_email_addresses.email)
      UNION
      SELECT ppl.id as person_id, dups.id as dup_person_id
      FROM account_ppl as ppl
        INNER JOIN account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN phone_numbers ON phone_numbers.person_id = ppl.id
        INNER JOIN phone_numbers as dup_phone_numbers ON dup_phone_numbers.person_id = dups.id
      WHERE phone_numbers.number = dup_phone_numbers.number
    ) dup_ppl_by_contact_info_query;
    CREATE INDEX ON dup_ppl_by_contact_info (person_id);
    CREATE INDEX ON dup_ppl_by_contact_info (dup_person_id);

    SELECT ppl_names.id, AVG(name_male_ratios.male_ratio) as male_ratio
    INTO TEMP ppl_name_male_ratios
    FROM ppl_names
    LEFT JOIN name_male_ratios ON ppl_names.name = name_male_ratios.name
    GROUP BY ppl_names.id;

    SELECT dups.*
    INTO TEMP dup_ppl
    FROM (
      SELECT person_id, dup_person_id, nickname_id, priority, check_genders, name_source, dup_name_source
      FROM dup_ppl_by_name
      UNION
      SELECT person_id, dup_person_id, null, null, check_genders, null, null
      FROM dup_ppl_by_contact_info
    ) dups
    INNER JOIN people ON dups.person_id = people.id
    INNER JOIN people AS dup_people ON dups.dup_person_id = dup_people.id
    LEFT JOIN ppl_name_male_ratios name_male_ratios ON name_male_ratios.id = people.id
    LEFT JOIN ppl_name_male_ratios dup_name_male_ratios ON dup_name_male_ratios.id = dup_people.id
    WHERE check_genders = 'f'
        or (
              (name_male_ratios.male_ratio IS NULL OR dup_name_male_ratios.male_ratio IS NULL)
              AND (people.gender = dup_people.gender OR people.gender IS NULL OR dup_people.gender IS NULL)
            OR (name_male_ratios.male_ratio < 0.1 AND dup_name_male_ratios.male_ratio < 0.1)
            OR (name_male_ratios.male_ratio > 0.9 AND dup_name_male_ratios.male_ratio > 0.9));
  "

  DUP_PEOPLE_NEW_SQL = "
    SELECT dup_ppl.person_id, dup_person_id, nickname_id, contact_people.contact_id,
      case
        when dup_ppl.priority is not null then dup_ppl.priority
        when contacts.name ilike ppl.last_name || ',%' then 10
         when ppl.last_name is not null and ppl.last_name <> '' then 5
         when ppl.id < dups.id then 3 else 1
      end as priority
    FROM dup_ppl
      INNER JOIN people ppl ON ppl.id = dup_ppl.person_id
      INNER JOIN people dups ON dups.id = dup_ppl.dup_person_id
      INNER JOIN contact_people ON contact_people.person_id = dup_ppl.person_id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = dup_ppl.dup_person_id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
    WHERE contact_people.contact_id = dup_contact_people.contact_id
    and contacts.name NOT ilike ('%' || ppl.first_name || '% and %' || dups.first_name || '%')
      and contacts.name NOT ilike ('%' || dups.first_name || '% and %' || ppl.first_name || '%')
      ORDER BY priority desc;"

  DUP_CONTACTS_SQL = "
    SELECT contact_people.contact_id, dup_contact_people.contact_id dup_contact_id
    FROM dup_ppl
    INNER JOIN contact_people ON contact_people.person_id = dup_ppl.person_id
    INNER JOIN contact_people dup_contact_people ON dup_contact_people.person_id = dup_ppl.dup_person_id
    WHERE contact_people.contact_id <> dup_contact_people.contact_id
      and coalesce(dup_ppl.name_source, '') <> 'middle' and coalesce(dup_ppl.dup_name_source, '') <> 'middle'
    UNION
    SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN contacts as dup_contacts ON contacts.id < dup_contacts.id
      INNER JOIN addresses
        ON addresses.addressable_type = 'Contact' AND addresses.addressable_id = contacts.id
      INNER JOIN addresses as dup_addresses
        ON dup_addresses.addressable_type = 'Contact' AND dup_addresses.addressable_id = dup_contacts.id
    WHERE
      contacts.account_list_id = :account_list_id AND dup_contacts.account_list_id = :account_list_id
      AND contacts.name not like '%nonymous%' AND dup_contacts.name not like '%nonymous%'
      AND addresses.primary_mailing_address = 't'
      AND dup_addresses.primary_mailing_address = 't'
      AND addresses.master_address_id = dup_addresses.master_address_id;
  "

  def initialize(account_list)
    @account_list = account_list
  end

  def dup_contacts_then_people
    statements = CREATE_TEMP_TABLES.gsub(':account_list_id', Contact.connection.quote(@account_list.id)).split(';')
    statements.each do |sql|
      Person.connection.exec_query(sql)
    end

    contacts = dup_contact_sets
    return [contacts, []] unless contacts.empty?

    contacts_and_people = [[], dup_people_sets]

    # Drop temp tables

    contacts_and_people
  end

  # The reason these are large queries and not Ruby code with loops is that as I introduced more duplicate
  # search options, that code got painfully slow and so I re-wrote the logic as self-join queries for performance.

  def dup_contact_sets
    sql = DUP_CONTACTS_SQL.gsub(':account_list_id', Contact.connection.quote(@account_list.id))
    contact_id_pairs = Person.connection.exec_query(sql).rows

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
end
