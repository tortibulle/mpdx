class GoogleContact < ActiveRecord::Base
  belongs_to :person
  belongs_to :google_account, class_name: 'Person::GoogleAccount'
  belongs_to :picture

  serialize :last_data, Hash
  serialize :last_mappings, Hash
end
