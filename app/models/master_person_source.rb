class MasterPersonSource < ActiveRecord::Base
  belongs_to :master_person
  belongs_to :organization

  # attr_accessible :master_person_id
end
