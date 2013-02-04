class ContactPerson < ActiveRecord::Base
  include HasPrimary
  @@primary_scope = :contact

  belongs_to :contact, touch: true
  belongs_to :person

  after_commit :delete_orphaned_person, on: :destroy

  private

  def delete_orphaned_person
    # See if there is any other contact_person with the same person id
    unless ContactPerson.where(person_id: person_id).where('id <> ?', id).first
      # if there isn't, delete the associated person
      person.destroy if person
    end
  end

end
