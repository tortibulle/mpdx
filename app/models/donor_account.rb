require_dependency 'address_methods'
class DonorAccount < ActiveRecord::Base
  include AddressMethods

  has_many :master_person_donor_accounts, dependent: :destroy
  has_many :master_people, through: :master_person_donor_accounts
  has_many :donor_account_people, dependent: :destroy
  has_many :people, through: :donor_account_people
  has_many :donations, dependent: :destroy
  has_many :contact_donor_accounts, dependent: :destroy
  has_many :contacts, through: :contact_donor_accounts
  belongs_to :organization
  belongs_to :master_company

  def primary_master_person
    master_people.where('master_person_donor_accounts.primary' => true).first
  end

  def link_to_contact_for(account_list, contact = nil)
    contact ||= account_list.contacts.where('donor_accounts.id' => id).includes(:donor_accounts).first # already linked

    # Try to find a contact for this user that matches based on name
    contact ||= account_list.contacts.detect { |c| c.name == name }

    contact ||= Contact.create_from_donor_account(self, account_list)
    contact.donor_accounts << self unless contact.donor_accounts.include?(self)
    contact
  end

  def update_donation_totals(donation)
    self.first_donation_date = donation.donation_date if first_donation_date.nil? || donation.donation_date < first_donation_date
    self.last_donation_date = donation.donation_date if last_donation_date.nil? || donation.donation_date > last_donation_date
    self.total_donations = self.total_donations.to_f + donation.amount
    save(validate: false)
  end

end
