# This class provides the flexibility needed for one person to have
# multiple designation accounts in multiple countries. In that scenario
# it didn't make sense to associate a contact with a designation
# account. It also doesn't work to associate the contact with a user
# account because (for example) a husband and wife will both want to see
# the same contacts. So for most users, an AccountList will contain only
# one account, and the notion of an AccountList will be hidden from the
# user. This concept should only be exposed to users who have more than
# one designation account.

require 'async'

class AccountList < ActiveRecord::Base
  include Async

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  has_many :account_list_users, dependent: :destroy
  has_many :users, through: :account_list_users
  has_many :account_list_entries, dependent: :destroy
  has_many :designation_accounts, through: :account_list_entries
  has_many :contacts, dependent: :destroy
  has_many :notifications, through: :contacts
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
  has_one  :mail_chimp_account, dependent: :destroy
  has_many :notification_preferences, autosave: true

  belongs_to :designation_profile

  attr_accessible :name, :creator_id, :contacts_attributes

  accepts_nested_attributes_for :contacts, reject_if: :all_blank, allow_destroy: true

  def self.queue() :import; end

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

  def contact_tags
    @contact_tags ||= ActiveRecord::Base.connection.select_values("select distinct(tags.name) from account_lists al inner join contacts c on c.account_list_id = al.id inner join taggings t on t.taggable_id = c.id AND t.taggable_type = 'Contact'
                                            inner join tags on t.tag_id = tags.id where al.id = #{id} order by tags.name")
  end

  def activity_tags
    @contact_tags ||= ActiveRecord::Base.connection.select_values("select distinct(tags.name) from account_lists al inner join activities a on a.account_list_id = al.id inner join taggings t on t.taggable_id = a.id AND t.taggable_type = 'Activity'
                                            inner join tags on t.tag_id = tags.id where al.id = #{id} order by tags.name")
  end

  def cities
    @cities ||= ActiveRecord::Base.connection.select_values("select distinct(a.city) from account_lists al inner join contacts c on c.account_list_id = al.id
                                                       inner join addresses a on a.addressable_id = c.id AND a.addressable_type = 'Contact' where al.id = #{id}
                                                       order by a.city")
  end

  def states
    @states ||= ActiveRecord::Base.connection.select_values("select distinct(a.state) from account_lists al inner join contacts c on c.account_list_id = al.id
                                                       inner join addresses a on a.addressable_id = c.id AND a.addressable_type = 'Contact' where al.id = #{id}
                                                       order by a.state")
  end

  def churches
    @churches ||= ActiveRecord::Base.connection.select_values("select distinct(c.church_name) from account_lists al inner join contacts c on c.account_list_id = al.id
                                                       where al.id = #{id} order by c.church_name")
  end

  def valid_mail_chimp_account
    mail_chimp_account.try(:active?) && mail_chimp_account.primary_list
  end

  def top_partners
    contacts.order('total_donations desc')
    .where('total_donations > 0')
    .limit(10)
  end

  # Download all donations / info for all accounts associated with this list
  def self.update_linked_org_accounts
    AccountList.find_each do |al|
      al.users.collect(&:organization_accounts).flatten.uniq.collect(&:queue_import_data)
    end
  end

  def self.queue_send_account_notifications
    AccountList.find_each { |al| al.async(:send_account_notifications) }
  end

  def merge(other)
    AccountList.transaction do
      designation_profile.merge(other.designation_profile)

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

      unless mail_chimp_account
        if other.mail_chimp_account
          other.mail_chimp_account.update_attributes({account_list_id: id}, without_protection: true)
        end
      end

      save(validate: false)
      other.reload
      other.destroy
    end
  end

  private

  # trigger any notifications for designation accounts in this account list
  def send_account_notifications
    designation_accounts.each do |da|
      notifications = NotificationType.check_all(da)

      notifications_to_email = {}

      # Check preferences for what to do with each notification type
      NotificationType.types.each do |notification_type_string|
        notification_type = notification_type_string.constantize.first

        if notifications[notification_type_string].present?
          actions = notification_preferences.find_by_notification_type_id(notification_type.id).try(:actions) ||
            NotificationPreference.default_actions

          # Collect any emails that need sent
          if actions.include?('email')
            notifications_to_email[notification_type] = notifications[notification_type_string]
          end

          if actions.include?('task')
            # Create a task for each notification
            notifications[notification_type_string].each do |notification|
              notification_type.create_task(self, notification)
            end
          end
        end
      end

      # Send email if necessary
      if notifications_to_email.present?
        NotificationMailer.notify(self, notifications_to_email).deliver
      end
    end
  end

end
