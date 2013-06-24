class MasterAddress < ActiveRecord::Base
  has_many :addresses
  serialize :smarty_response, JSON
end
