require 'ostruct'

class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  def dup_contacts_and_people
    nickname_dups = dup_people_by_nickname

    increment_nicknames_offered(nickname_dups.map(&:nickname_id))

    dup_people_pairs = dup_people_by_same_name + nickname_dups.map { |dup| [dup.person.id, dup.dup_person.id] }
    contact_sets = dup_contacts(dup_people_pairs)

    # Only show duplicated people if they are in the same contact. If they're in different contacts, the user should consider
    # merging the whole contacts first, then they can merge the duplicated people within them (and those with the
    # same name would be automatically merged anyway).
    people_sets = nickname_dups.select { |dup| dup.shared_contact.present? }

    [contact_sets, people_sets]
  end

  def increment_nicknames_offered(nickname_ids)
    return if nickname_ids.empty?
    sql = "UPDATE nicknames SET num_times_offered = num_times_offered + 1 WHERE id IN (#{nickname_ids.join(',')})"
    ActiveRecord::Base.connection.execute(sql)
  end

  def dup_people_by_same_name
    # Find sets of people with the same name
    sql = "SELECT array_to_string(array_agg(people.id), ',')
               FROM people
               INNER JOIN contact_people ON people.id = contact_people.person_id
               INNER JOIN contacts ON contact_people.contact_id = contacts.id
               WHERE contacts.account_list_id = #{@account_list.id}
               AND name not like '%nonymous%'
               AND first_name not like '%nknow%'
               GROUP BY first_name, last_name
               HAVING count(*) > 1"
    Person.connection.select_values(sql).map { |dup_person_ids| dup_person_ids.split(',').map(&:to_i) }
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

  def dup_contacts(dup_people_pairs)
    contact_sets = []
    contacts_checked = []
    dup_people_pairs.each do |pair|
      contacts = @account_list.contacts.people.includes(:people).where('people.id' => pair).references('people')[0..1]
      next if contacts.length <= 1
      already_included = false
      contacts.each { |c| already_included = true if contacts_checked.include?(c) }
      next if already_included
      contacts_checked += contacts
      contact_sets << contacts unless contacts.first.not_same_as?(contacts.last)
    end
    contact_sets.sort_by! { |s| s.first.name }
  end
end
