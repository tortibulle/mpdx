class Appeal < ActiveRecord::Base
  belongs_to :account_list
  has_many :appeal_contacts
  has_many :contacts, through: :appeal_contacts
  has_many :donations

  validates :account_list_id, presence: true

  PERMITTED_ATTRIBUTES = [:id, :name, :amount, :description, :end_date, :account_list_id]

  def add_contacts(account_list, contact_ids)
    valid_contact_ids = account_list.contacts.pluck(:id) & contact_ids
    new_contact_ids = valid_contact_ids - contacts.pluck(:id)
    new_contact_ids.each do |contact_id|
      return false unless AppealContact.new(appeal_id: self.id, contact_id: contact_id).save
    end
  end
end
