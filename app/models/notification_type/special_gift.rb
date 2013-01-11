class NotificationType::SpecialGift < NotificationType

  def check(designation_account)
    notifications = []
    designation_account.contacts.non_financial_partners.each do |contact|
      if donation = contact.donations.for(designation_account).where("donation_date > ?", 2.weeks.ago).order('donations.donation_date desc').last
        prior_notification = Notification.active.where(contact_id: contact.id, notification_type_id: id, donation_id: donation.id).first
        unless prior_notification
          notification = contact.notifications.create!(notification_type_id: id, donation_id: donation.id, event_date: Date.today)
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
    _("%{contact_name} just gave a Special Gift. Send them a Thank You.") %
      { contact_name: contact.name }
  end

end

