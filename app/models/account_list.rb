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
  include Sidekiq::Worker
  sidekiq_options queue: :import, retry: false, unique: true

  store :settings, accessors: [:monthly_goal, :tester, :owner]

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  has_many :account_list_users, dependent: :destroy
  has_many :users, through: :account_list_users
  has_many :organization_accounts, through: :users
  has_many :account_list_entries, dependent: :destroy
  has_many :designation_accounts, through: :account_list_entries
  has_many :contacts, dependent: :destroy
  has_many :active_contacts, -> { where(Contact.active_conditions) }, class_name: 'Contact'
  has_many :notifications, through: :contacts
  has_many :addresses, through: :contacts
  has_many :people, through: :contacts
  has_many :active_people, through: :active_contacts, source: :people, class_name: 'Person'
  has_many :master_people, through: :people
  has_many :donor_accounts, through: :contacts
  has_many :company_partnerships, dependent: :destroy
  has_many :companies, through: :company_partnerships
  has_many :tasks
  has_many :activities, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_one  :mail_chimp_account, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy, autosave: true
  has_many :messages
  has_many :designation_profiles
  has_one :prayer_letters_account, dependent: :destroy, autosave: true
  has_many :google_integrations, dependent: :destroy

  accepts_nested_attributes_for :contacts, reject_if: :all_blank, allow_destroy: true

  def self.find_with_designation_numbers(numbers, organization)
    designation_account_ids = DesignationAccount.where(designation_number: numbers, organization_id: organization.id).pluck(:id).sort
    results = AccountList.connection.select_all("select account_list_id,array_to_string(array_agg(designation_account_id), ',') as designation_account_ids from account_list_entries group by account_list_id")
    results.each do |hash|
      if hash['designation_account_ids'].split(',').map(&:to_i).sort == designation_account_ids
        return AccountList.find(hash['account_list_id'])
      end
    end
    nil
  end

  def monthly_goal=(val)
    settings[:monthly_goal] = val.gsub(/[^\d\.]/, '').to_i if val
  end

  def monthly_goal
    settings[:monthly_goal].present? && settings[:monthly_goal].to_i > 0 ? settings[:monthly_goal].to_i : nil
  end

  def multiple_designations
    designation_accounts.length > 1 ? true : false
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
                                                       AND (#{Contact.active_conditions})
                                                       order by a.city")
  end

  def states
    @states ||= ActiveRecord::Base.connection.select_values("select distinct(a.state) from account_lists al inner join contacts c on c.account_list_id = al.id
                                                       inner join addresses a on a.addressable_id = c.id AND a.addressable_type = 'Contact' where al.id = #{id}
                                                       AND (#{Contact.active_conditions})
                                                       order by a.state")
  end

  def churches
    @churches ||= ActiveRecord::Base.connection.select_values("select distinct(c.church_name) from account_lists al inner join contacts c on c.account_list_id = al.id
                                                       where al.id = #{id}
                                                       AND (#{Contact.active_conditions})
                                                       order by c.church_name")
  end

  def valid_mail_chimp_account
    mail_chimp_account.try(:active?) && mail_chimp_account.primary_list.present?
  end

  def valid_prayer_letters_account
    prayer_letters_account.try(:valid_token?)
  end

  def top_partners
    contacts.order('total_donations desc')
    .where('total_donations > 0')
    .limit(10)
  end

  def donations
    if designation_account_ids.present?
      Donation.where(donor_account_id: donor_account_ids, designation_account_id: designation_account_ids)
    else
      Donation.where(donor_account_id: donor_account_ids)
    end
  end

  def designation_profile(user)
    designation_profiles.where(user_id: user.id).first
  end

  def total_pledges
    @total_pledges ||= contacts.financial_partners.to_a.sum(&:monthly_pledge)
    @total_pledges.round(2)
  end

  def people_with_birthdays(start_date, end_date)
    start_month = start_date.month
    end_month = end_date.month
    if start_month == end_month
      people_with_birthdays = people.where("people.birthday_month = ?", start_month)
                                    .where("people.birthday_day BETWEEN ? AND ?", start_date.day, end_date.day)
    else
      people_with_birthdays = people.where("(people.birthday_month = ? AND people.birthday_day >= ?)
                                           OR (people.birthday_month = ? AND people.birthday_day <= ?)",
                                           start_month, start_date.day, end_month, end_date.day)

    end
    people_with_birthdays.order('people.birthday_month, people.birthday_day').merge(contacts.active)
  end

  def people_with_anniversaries(start_date, end_date)
    start_month = start_date.month
    end_month = end_date.month
    if start_month == end_month
      people_with_birthdays = people.where("people.anniversary_month = ?", start_month)
                                    .where("people.anniversary_day BETWEEN ? AND ?", start_date.day, end_date.day)
    else
      people_with_birthdays = people.where("(people.anniversary_month = ? AND people.anniversary_day >= ?)
                                           OR (people.anniversary_month = ? AND people.anniversary_day <= ?)",
                                           start_month, start_date.day, end_month, end_date.day)

    end
    people_with_birthdays.order('people.anniversary_month, people.anniversary_day').merge(contacts.active)
  end

  def top_50_percent
    unless @top_50_percent
      financial_partners_count = contacts.where("pledge_amount > 0").count
      @top_50_percent = contacts.where("pledge_amount > 0")
                                .order('(pledge_amount::numeric / (pledge_frequency::numeric)) desc')
                                .limit(financial_partners_count / 2)
    end
    @top_50_percent
  end

  def bottom_50_percent
    unless @bottom_50_percent
      financial_partners_count = contacts.where("pledge_amount > 0").count
      @bottom_50_percent = contacts.where("pledge_amount > 0")
                                .order('(pledge_amount::numeric / (pledge_frequency::numeric))')
                                .limit(financial_partners_count / 2)
    end
    @bottom_50_percent
  end


  def no_activity_since(date, contacts_scope = nil, activity_type = nil)
    @no_activity_since = []
    contacts_scope ||= contacts
    contacts_scope.includes({people: [:primary_phone_number, :primary_email_address]}).each do |contact|
      activities = contact.tasks.where("completed_at > ?", date)
      activities = activities.where("activity_type = ?", activity_type) if activity_type.present?
      @no_activity_since << contact if activities.blank?
    end
    @no_activity_since
  end

  def merge_contacts
    merged_contacts = []

    ordered_contacts = contacts.includes(:addresses, :donor_accounts).order('contacts.created_at')
    ordered_contacts.each do |contact|
      next if merged_contacts.include?(contact)

      other_contacts = ordered_contacts.find_all {|c| c.name == contact.name &&
                                                           c.id != contact.id &&
                                                           (c.donor_accounts.first == contact.donor_accounts.first ||
                                                            c.addresses.detect {|a| contact.addresses.detect {|ca| ca == a}}) }
      if other_contacts.present?
        other_contacts.each do |other_contact|
          contact.merge(other_contact)
          merged_contacts << other_contact
        end
      end
    end

    contacts.reload
    contacts.map(&:merge_people)
    contacts.map(&:merge_addresses)
  end

  # Download all donations / info for all accounts associated with this list
  def self.update_linked_org_accounts
    AccountList.joins(:organization_accounts)
               .where("locked_at is null").order('last_download asc')
               .each do |al|
      al.async(:import_data)
    end
  end


  def self.find_or_create_from_profile(profile, org_account)
    user = org_account.user
    organization = org_account.organization
    designation_numbers = profile.designation_accounts.collect(&:designation_number)
    # look for an existing account list with the same designation numbers in it
    unless account_list = AccountList.find_with_designation_numbers(designation_numbers, organization)
      # create a new list for this profile
      account_list = AccountList.where(name: profile.name, creator_id: user.id).first_or_create!
    end

    # Add designation accounts to account_list
    profile.designation_accounts.each do |da|
      account_list.designation_accounts << da unless account_list.designation_accounts.include?(da)
    end

    # Add user to account list
    account_list.users << user unless account_list.users.include?(user)
    profile.update_attributes(account_list_id: account_list.id)

    account_list
  end

  def merge(other)
    AccountList.transaction do
      other.designation_profiles.update_all(account_list_id: id)
      other.messages.update_all(account_list_id: id)

      other.users.each do |user|
        unless users.include?(user)
          users << user
          user.update_attributes(preferences: nil)
        end
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
          other.mail_chimp_account.update_attributes({account_list_id: id})
        end
      end
      other.reload
      other.destroy

      save(validate: false)
    end
  end

  # This method checks all of your donors and tries to intelligently determin which partners are regular givers
  # based on thier giving history.
  def update_partner_statuses
    contacts.where(status: nil).joins(:donor_accounts).each do |contact|
      # If they have a donor account id, they are at least a special donor
      # If they have given the same amount for the past 3 months, we'll assume they are
      # a monthly donor.
      gifts = donations.where(donor_account_id: contact.donor_account_ids,
                              designation_account_id: designation_account_ids).
                        order('donation_date desc')
      latest_donation = gifts[0]

      next unless latest_donation

      pledge_frequency = contact.pledge_frequency
      pledge_amount = contact.pledge_amount

      if latest_donation.donation_date.to_time > 2.months.ago && latest_donation.channel == 'Recurring'
        status = 'Partner - Financial'
        pledge_frequency = 1 unless contact.pledge_frequency
        pledge_amount = latest_donation.amount unless contact.pledge_amount.to_i > 0
      else
        status = 'Partner - Special'
      end

      # Re-query the contact to make it not read-only from the join
      # (there are other ways to handle that, but this one was easy)
      Contact.find(contact.id).update_attributes(status: status, pledge_frequency: pledge_frequency, pledge_amount: pledge_amount)
    end
  end

  def all_contacts
    unless @all_contacts
      @all_contacts = contacts.order('contacts.name')
      @all_contacts.select(['contacts.id', 'contacts.name'])
    end
    @all_contacts
  end

  def cache_key
    super + total_pledges.to_s
  end

  private

  def import_data
    users.collect(&:organization_accounts).flatten.uniq.map(&:import_all_data)
    send_account_notifications
  end

  # trigger any notifications for this account list
  def send_account_notifications
    notifications = NotificationType.check_all(self)

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
