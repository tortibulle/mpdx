class Appeal < ActiveRecord::Base
  belongs_to :account_list
  has_many :appeal_contacts
  has_many :contacts, through: :appeal_contacts

  has_many :appeal_donations
  has_many :donations, through: :appeal_donations

  PERMITTED_ATTRIBUTES = [:id, :name, :amount, :description, :end_date, {
      activity_contacts_attributes: [:contact_id, :_destroy]
  }]

  accepts_nested_attributes_for :contacts, reject_if: :all_blank, allow_destroy: true
end
