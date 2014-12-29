require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  # To help prevent merging a male person with a female person (and because the gender field can be unreliable),
  # we use the name_male_ratios table which has data on male ratios of people. To avoid false positives with
  # duplicate matching, require a certain threshold of the name ratio to confidently assume the person is male/female
  # for the sake of suggesting duplicates.
  MALE_NAME_CONFIDENCE_LVL = 0.9 # Assume male if more than this ratio with name are male
  FEMALE_NAME_CONFIDENCE_LVL  = 0.1 # Assume female if fewer than this ratio with name are male

  def dup_contacts_then_people
    create_temp_tables

    contacts = dup_contact_sets
    return [contacts, []] unless contacts.empty?

    contacts_and_people = [[], dup_people_sets]

    drop_temp_tables_if_exist

    contacts_and_people
  end

  private

  def dup_contact_sets
    contact_id_pairs = dup_contacts_query

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

  def dup_people_rows
    # Eliminate duplicates but keep the rows which are first
    dup_pairs_so_far = Set.new
    dup_people_query.reject do |row|
      dup_set = [row[:person_id], row[:dup_person_id]].sort
      already_included = dup_pairs_so_far.include?(dup_set)

      dup_pairs_so_far << dup_set

      already_included
    end
  end

  def exec_query(sql)
    Person.connection.exec_query(sql.gsub(':account_list_id', Person.connection.quote(@account_list.id)))
  end

  # The reason these are large queries with temp tables and not Ruby code with loops is that as I introduced more
  # duplicate search options, that code got painfully slow and so I re-wrote the logic as self-join queries for performance.
  CREATE_TEMP_TABLES = [
    "SELECT people.id, first_name, legal_first_name, middle_name, last_name
    INTO TEMP tmp_account_ppl
    FROM people
      INNER JOIN contact_people ON people.id = contact_people.person_id
      INNER JOIN contacts ON contacts.id = contact_people.contact_id
    WHERE contacts.account_list_id = :account_list_id
      and contacts.name not like '%nonymous%'
      and people.first_name not like '%nknow%'",

    'CREATE INDEX ON tmp_account_ppl (id)',

    "SELECT *
    INTO TEMP tmp_unsplit_names
    FROM (
      SELECT first_name as name, 'first' as name_source, id, first_name, last_name FROM tmp_account_ppl
      UNION SELECT legal_first_name, 'first' as name_source, id, first_name, last_name FROM tmp_account_ppl
        WHERE legal_first_name is not null and legal_first_name <> ''
      UNION SELECT middle_name, 'middle' as name_source, id, first_name, last_name FROM tmp_account_ppl
        WHERE middle_name is not null and middle_name <> ''
    ) as people_unsplit_names_query",

    "SELECT lower(name) as name, name_source, id, first_name, lower(last_name) as last_name
    INTO TEMP tmp_names
    FROM (
      SELECT replace(name, ' ', '') as name, name_source, id, first_name, last_name FROM tmp_unsplit_names
      UNION SELECT regexp_split_to_table(regexp_replace(name, '[\\.-]+$', ''), '([\\. -]+|$)+'),
        name_source, id, first_name, last_name
      FROM tmp_unsplit_names WHERE name ~ '[\\. -]'
      UNION SELECT regexp_split_to_table(regexp_replace(name, '(^[A-Z]|[a-z])([A-Z])', '\\1 \\2'), ' '),
        name_source, id, first_name, last_name
      FROM tmp_unsplit_names WHERE name ~ '(^[A-Z]|[a-z])([A-Z])' and name !~ '[A-Z]{3}'
    ) as people_names_query",

    'CREATE INDEX ON tmp_names (id)',
    'CREATE INDEX ON tmp_names (name)',
    'CREATE INDEX ON tmp_names (last_name)',

    "SELECT ppl.id as person_id, dups.id as dup_person_id, nicknames.id as nickname_id,
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
    INTO TEMP tmp_dups_by_name
    FROM tmp_names as ppl
      INNER JOIN tmp_names as dups ON ppl.id <> dups.id
      LEFT JOIN nicknames ON nicknames.suggest_duplicates = 't'
        and ((ppl.name = nicknames.nickname and dups.name = nicknames.name)
          or (ppl.name = nicknames.name and dups.name = nicknames.nickname))
    WHERE ppl.last_name = dups.last_name
      and (ppl.name_source = 'first' or dups.name_source = 'first')
      and (
        nicknames.id is not null
        or (dups.name = ppl.name and char_length(ppl.name) > 1)
        or ((char_length(dups.name) = 1 or char_length(ppl.name) = 1)
          and (dups.name = substring(ppl.name from 1 for 1) or ppl.name = substring(dups.name from 1 for 1))))",

    'CREATE INDEX ON tmp_dups_by_name (person_id)',
    'CREATE INDEX ON tmp_dups_by_name (dup_person_id)',

    'SELECT *, true as check_genders
    INTO TEMP tmp_dups_by_contact_info
    FROM (
      SELECT ppl.id as person_id, dups.id as dup_person_id
      FROM tmp_account_ppl as ppl
        INNER JOIN tmp_account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN email_addresses ON email_addresses.person_id = ppl.id
        INNER JOIN email_addresses as dup_email_addresses ON dup_email_addresses.person_id = dups.id
      WHERE lower(email_addresses.email) = lower(dup_email_addresses.email)
      UNION
      SELECT ppl.id as person_id, dups.id as dup_person_id
      FROM tmp_account_ppl as ppl
        INNER JOIN tmp_account_ppl as dups ON ppl.id <> dups.id
        INNER JOIN phone_numbers ON phone_numbers.person_id = ppl.id
        INNER JOIN phone_numbers as dup_phone_numbers ON dup_phone_numbers.person_id = dups.id
      WHERE phone_numbers.number = dup_phone_numbers.number
    ) tmp_dups_by_contact_info_query',
    'CREATE INDEX ON tmp_dups_by_contact_info (person_id)',
    'CREATE INDEX ON tmp_dups_by_contact_info (dup_person_id)',

    'SELECT tmp_names.id, AVG(name_male_ratios.male_ratio) as male_ratio
    INTO TEMP tmp_name_male_ratios
    FROM tmp_names
    LEFT JOIN name_male_ratios ON tmp_names.name = name_male_ratios.name
    GROUP BY tmp_names.id',

    "SELECT dups.*
    INTO TEMP tmp_dups
    FROM (
      SELECT person_id, dup_person_id, nickname_id, priority, check_genders, name_source, dup_name_source
      FROM tmp_dups_by_name
      UNION
      SELECT person_id, dup_person_id, null, null, check_genders, null, null
      FROM tmp_dups_by_contact_info
    ) dups
    INNER JOIN people ON dups.person_id = people.id
    INNER JOIN people AS dup_people ON dups.dup_person_id = dup_people.id
    LEFT JOIN tmp_name_male_ratios name_male_ratios ON name_male_ratios.id = people.id
    LEFT JOIN tmp_name_male_ratios dup_name_male_ratios ON dup_name_male_ratios.id = dup_people.id
    WHERE check_genders = 'f'
        or (
            (name_male_ratios.male_ratio IS NULL or dup_name_male_ratios.male_ratio IS NULL)
              and (people.gender = dup_people.gender or people.gender IS NULL or dup_people.gender IS NULL)
            or (
              name_male_ratios.male_ratio < #{FEMALE_NAME_CONFIDENCE_LVL}
              and dup_name_male_ratios.male_ratio < #{FEMALE_NAME_CONFIDENCE_LVL})
            or (
              name_male_ratios.male_ratio > #{MALE_NAME_CONFIDENCE_LVL}
              and dup_name_male_ratios.male_ratio > #{MALE_NAME_CONFIDENCE_LVL}))",
    'CREATE INDEX ON tmp_dups (person_id)',
    'CREATE INDEX ON tmp_dups (dup_person_id)'
  ]

  def create_temp_tables
    drop_temp_tables_if_exist
    CREATE_TEMP_TABLES.each(&method(:exec_query))
  end

  DUP_CONTACTS_SQL = "
    SELECT contact_people.contact_id, dup_contact_people.contact_id dup_contact_id
    FROM tmp_dups
    INNER JOIN contact_people ON contact_people.person_id = tmp_dups.person_id
    INNER JOIN contact_people dup_contact_people ON dup_contact_people.person_id = tmp_dups.dup_person_id
    WHERE contact_people.contact_id <> dup_contact_people.contact_id
      and coalesce(tmp_dups.name_source, '') <> 'middle' and coalesce(tmp_dups.dup_name_source, '') <> 'middle'
    UNION
    SELECT contacts.id, dup_contacts.id
    FROM contacts
      INNER JOIN contacts as dup_contacts ON contacts.id < dup_contacts.id
      INNER JOIN addresses
        ON addresses.addressable_type = 'Contact' and addresses.addressable_id = contacts.id
      INNER JOIN addresses as dup_addresses
        ON dup_addresses.addressable_type = 'Contact' and dup_addresses.addressable_id = dup_contacts.id
    WHERE
      contacts.account_list_id = :account_list_id and dup_contacts.account_list_id = :account_list_id
      and contacts.name not like '%nonymous%' and dup_contacts.name not like '%nonymous%'
      and addresses.primary_mailing_address = 't'
      and dup_addresses.primary_mailing_address = 't'
      and addresses.master_address_id = dup_addresses.master_address_id"
  def dup_contacts_query
    exec_query(DUP_CONTACTS_SQL).rows
  end

  DUP_PEOPLE_NEW_SQL = "
    SELECT tmp_dups.person_id, dup_person_id, nickname_id, contact_people.contact_id,
      case
        when tmp_dups.priority is not null then tmp_dups.priority
        when contacts.name ilike ppl.last_name || ',%' then 10
         when ppl.last_name is not null and ppl.last_name <> '' then 5
         when ppl.id < dups.id then 3 else 1
      end as priority
    FROM tmp_dups
      INNER JOIN people ppl ON ppl.id = tmp_dups.person_id
      INNER JOIN people dups ON dups.id = tmp_dups.dup_person_id
      INNER JOIN contact_people ON contact_people.person_id = tmp_dups.person_id
      INNER JOIN contact_people as dup_contact_people ON dup_contact_people.person_id = tmp_dups.dup_person_id
      INNER JOIN contacts ON contact_people.contact_id = contacts.id
    WHERE contact_people.contact_id = dup_contact_people.contact_id
    and contacts.name NOT ilike ('%' || ppl.first_name || '% and %' || dups.first_name || '%')
      and contacts.name NOT ilike ('%' || dups.first_name || '% and %' || ppl.first_name || '%')
      ORDER BY priority desc"
  def dup_people_query
    exec_query(DUP_PEOPLE_NEW_SQL).to_hash.map(&:symbolize_keys)
  end

  def drop_temp_tables_if_exist
    [
      'DROP TABLE IF EXISTS tmp_account_ppl',
      'DROP TABLE IF EXISTS tmp_unsplit_names',
      'DROP TABLE IF EXISTS tmp_names',
      'DROP TABLE IF EXISTS tmp_dups_by_name',
      'DROP TABLE IF EXISTS tmp_dups_by_contact_info',
      'DROP TABLE IF EXISTS tmp_name_male_ratios',
      'DROP TABLE IF EXISTS tmp_dups'
    ].each(&method(:exec_query))
  end
end
