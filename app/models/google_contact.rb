class GoogleContact < ActiveRecord::Base
  belongs_to :person
  has_one :source_google_account, class_name: 'Person::GoogleAccount', foreign_key: :source_google_account_id
end
