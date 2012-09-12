# This class provides the flexibility needed for one person to have
# multiple designation accounts in multiple countries. In that scenario
# it didn't make sense to associate a contact with a designation
# account. It also doesn't work to associate the contact with a user
# account because (for example) a husband and wife will both want to see
# the same contacts. So for most users, an AccountList will contain only
# one account, and the notion of an AccountList will be hidden from the
# user. This concept should only be exposed to users who have more than
# one designation account.

class AccountList < ActiveRecord::Base
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  has_many :account_list_users, dependent: :destroy
  has_many :users, through: :account_list_users
  has_many :account_list_entries, dependent: :destroy
  has_many :designation_accounts, through: :account_list_entries
  has_many :contacts, dependent: :destroy
  has_many :addresses, through: :contacts
  has_many :people, through: :contacts
  has_many :master_people, through: :people
  has_many :donor_accounts, through: :contacts
  has_many :donations, through: :donor_accounts, :select => 'distinct donations.*'
  has_many :company_partnerships, dependent: :destroy
  has_many :companies, through: :company_partnerships
  has_many :tasks
  has_many :activities, dependent: :destroy
  has_many :imports, dependent: :destroy

  belongs_to :designation_profile

  attr_accessible :name, :creator_id

  def self.find_with_designation_numbers(numbers)
    designation_account_ids = DesignationAccount.where(designation_number: numbers).pluck(:id).sort
    results = AccountList.connection.select_all("select account_list_id,array_to_string(array_agg(designation_account_id), ',') as designation_account_ids from account_list_entries group by account_list_id")
    results.each do |hash|
      if hash['designation_account_ids'].split(',').map(&:to_i).sort == designation_account_ids
        return AccountList.find(hash['account_list_id'])
      end
    end
    nil
  end

  def tags
    #Rails.cache.fetch("account_tags/#{id}") do
    @tags ||= AccountList.connection.select_values("select distinct(tags.name) from account_lists al inner join contacts c on c.account_list_id = al.id inner join taggings t on t.taggable_id = c.id AND t.taggable_type = 'Contact'
                                            inner join tags on t.tag_id = tags.id where al.id = #{id}")
    #end
  end

  #def clear_tag_cache
    #Rails.cache.delete("account_tags/#{id}")
  #end

  def top_partners
    contacts.order('total_donations desc')
            .where('total_donations > 0')
            .limit(10)
  end

  def merge(other)
    AccountList.transaction do
      other.users.each do |user|
        users << user unless users.include?(user)
      end
      other.designation_accounts.each do |da|
        designation_accounts << da unless designation_accounts.include?(da)
      end
      other.contacts.update_all(account_list_id: id)
      other.companies.each do |company|
        companies << company unless companies.include?(company)
      end
      other.activities.update_all(account_list_id: id)

      save(validate: false)
      other.reload
      other.destroy
    end
  end
end
