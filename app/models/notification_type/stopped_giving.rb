class NotificationType::StoppedGiving < NotificationType

  # If the donor uses direct deposit, notify if it's been more than 31 + 14 days
  # (the extra 2 weeks is to allow for a delay in the donation system)
  # If a donor gives via check, notify when their gift is 30 days past due
  def check(designation_account, account_list)
    notifications = []
    designation_account.contacts(account_list_id: account_list.id).financial_partners.where(['pledge_start_date is NULL OR pledge_start_date < ?', 30.days.ago]).each do |contact|
      date = contact.direct_deposit? ? 60.days.ago : ((contact.pledge_frequency.to_i > 0 ? contact.pledge_frequency.to_i : 1) + 1).months.ago
      prior_notification = Notification.active.where(contact_id: contact.id, notification_type_id: id).first

      if contact.donations.for(designation_account).since(date).first
        # Clear a prior notification if there was one
        if prior_notification
          prior_notification.update_attributes(cleared: true)
          # Remove any tasks associated with this notification
          prior_notification.tasks.destroy_all
        end
      else
        unless prior_notification
          # If they've never given, they haven't missed a gift
          if contact.donations.for(designation_account).first
            notification = contact.notifications.create!(notification_type_id: id, event_date: Date.today)
            notifications << notification
          end
        end
      end
    end
    notifications
  end

  def create_task(account_list, notification)
    contact = notification.contact
    task = account_list.tasks.create(subject: task_description(notification), start_at: Time.now,
                                     activity_type: _('Call'), notification_id: notification.id)
    task.activity_contacts.create(contact_id: contact.id)
    task
  end

  def task_description(notification)
    _("%{contact_name} seems to have missed a gift. Call to follow up.") %
      { contact_name: notification.contact.name }
  end

end
