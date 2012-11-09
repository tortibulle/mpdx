class PreferenceSet
  include Virtus
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_reader :user, :account_list

  def initialize(*args)
    attributes = args.first
    @user = attributes[:user]
    @account_list = attributes[:account_list]
    super
  end

  # User preferences
  attribute :first_name, String, :default => lambda { |preference_set, attribute| preference_set.user.first_name }
  attribute :email, String, :default => lambda { |preference_set, attribute| preference_set.user.email }
  attribute :time_zone, String, :default => lambda { |preference_set, attribute| preference_set.user.time_zone }
  attribute :locale, String, :default => lambda { |preference_set, attribute| preference_set.user.locale }

  # AccountList preferences
  # - Notification Preferences
  attribute :notification_preferences, Array[NotificationPreference]

  validates :first_name, presence: true
  validates :email, presence: true


  def persisted?
    false
  end

  def stopped_giving=(val)
    set_preference(NotificationType::StoppedGiving, val)
  end

  def save
    if valid?
      persist!
      true
    else
      false
    end
  end

  # Handle our dynamic list of notification types
  def method_missing(method, *args, &blk) # {{{
    class_name = 'NotificationType::' + method.to_s.camelize
    if NotificationType.types.include?(class_name)
      type = class_name.constantize.first
      account_list.notification_preferences.detect { |p| p.notification_type_id == type.id }.try(:actions) ||
      ['email','task']
    else
      super
    end
  end

  def respond_to?(method, include_private = false)
    class_name = 'NotificationType::' + method.to_s.camelize
    NotificationType.types.include?(class_name) || super
  end

  private

  def set_preference(klass, val)
    type = klass.first
    preference = account_list.notification_preferences.detect { |p| p.notification_type_id == type.id } ||
                 account_list.notification_preferences.new(notification_type_id: type.id)
    preference.actions = val['actions']
    preference.save
  end

  def persist!
    user.update_attributes(first_name: first_name, email: email, time_zone: time_zone, locale: locale)
    account_list.save
  end
end
