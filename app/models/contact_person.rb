class ContactPerson < ActiveRecord::Base
  belongs_to :contact
  belongs_to :person
end
