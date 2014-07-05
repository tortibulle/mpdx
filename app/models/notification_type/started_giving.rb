class NotificationType::StartedGiving < NotificationType
  def check(account_list)
    notifications = []
    account_list.contacts.where(account_list_id: account_list.id).financial_partners.each do |contact|
      prior_notification = Notification.active.where(contact_id: contact.id, notification_type_id: id).first
      unless prior_notification
        # If they just gave their first gift, note it as such
        if !contact.pledge_received? &&
           (donation = contact.donations.for_accounts(account_list.designation_accounts).where('donation_date > ?', 2.weeks.ago).last) &&
           contact.donations.for_accounts(account_list.designation_accounts).where('donation_date < ?', 2.weeks.ago).count == 0

          # update pledge amount/received
          contact.pledge_amount = donation.amount if contact.pledge_amount.blank?
          contact.pledge_received = true if contact.pledge_amount == donation.amount
          contact.save

          notification = contact.notifications.create!(notification_type_id: id, event_date: Date.today)
          notifications << notification
        end
      end
    end
    notifications
  end

  def create_task(account_list, notification)
    contact = notification.contact
    task = account_list.tasks.create(subject: task_description(notification), start_at: Time.now,
                                     activity_type: _('Thank'), notification_id: notification.id)
    task.activity_contacts.create(contact_id: contact.id)
    task
  end

  def task_description(notification)
    _('%{contact_name} just gave their first gift. Send them a Thank You.').localize %
      { contact_name: notification.contact.name }
  end
end
