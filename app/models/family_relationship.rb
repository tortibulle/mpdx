class FamilyRelationship < ActiveRecord::Base
  belongs_to :person
  belongs_to :related_person, class_name: 'Person'

  # attr_accessible :related_person_id, :relationship

  def self.add_for_person(person, attributes)
    attributes = attributes.except(:_destroy)
    unless fr = person.family_relationships.where(related_person_id: attributes[:related_person_id]).first
      new_or_create = person.new_record? ? :new : :create
      fr = person.family_relationships.send(new_or_create, attributes)
    end
    fr
  end
end
