class MasterPersonSource < ActiveRecord::Base
  belongs_to :master_person
  belongs_to :organization
end
