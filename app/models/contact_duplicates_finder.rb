class ContactDuplicatesFinder
  def initialize(account_list)
    @account_list = account_list
  end

  def find_duplicate_people_pairs
    dup_people_by_same_name
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
    Person.connection.select_values(sql)
  end

  def dup_people_by_nickname

  end

  def find_duplicate_contacts
    contact_sets = []
    contacts_checked = []
    find_duplicate_people_pairs.each do |pair|
      contacts = @account_list.contacts.people.includes(:people)
                   .where('people.id' => pair.split(','))
                   .references('people')[0..1]
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
