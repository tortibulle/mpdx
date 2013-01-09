class NotificationType::StartedGiving < NotificationType

  def check(designation_account)
    notifications = []
    designation_account.contacts.financial_partners.each do |contact|
      prior_notification = Notification.active.where(contact_id: contact.id, notification_type_id: id).first
      unless prior_notification
        # If they just gave their first gift, note it as such
        if (donation = contact.donations.for(designation_account).where("donation_date > ?", 2.weeks.ago).last) &&
           contact.donations.for(designation_account).where("donation_date < ?", 2.weeks.ago).count == 0

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
    task = account_list.tasks.create(subject: task_description(contact), start_at: Time.now,
                                     activity_type: _('Thank'), notification_id: notification.id)
    task.activity_contacts.create(contact_id: contact.id)
    task
  end

  def task_description(contact)
    _("%{contact_name} just gave their first gift. Send them a Thank You.") %
      { contact_name: contact.name }
  end

end
