class NotificationType::StoppedGiving < NotificationType
  def check(account_list)
    notifications = []
    account_list.contacts.financial_partners.where(['pledge_start_date is NULL OR pledge_start_date < ?', 30.days.ago]).each do |contact|
      next unless contact.pledge_received?

      late = contact.late_by?(30.days)

      prior_notification = Notification.active.where(contact_id: contact.id, notification_type_id: id).first

      if late
        unless prior_notification
          # If they've never given, they haven't missed a gift
          if contact.donations.first
            notification = contact.notifications.create!(notification_type_id: id, event_date: Date.today)
            notifications << notification
          end
        end
      else
        # Clear a prior notification if there was one
        if prior_notification
          prior_notification.update_attributes(cleared: true)
          # Remove any tasks associated with this notification
          prior_notification.tasks.destroy_all
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
    _('%{contact_name} seems to have missed a gift. Call to follow up.').localize %
      { contact_name: notification.contact.name }
  end
end
