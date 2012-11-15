class NotificationType::StoppedGiving < NotificationType

  # If the donor uses direct deposit, notify if it's been more than 31 + 7 days
  # (the extra week is to allow for a delay in the donation system)
  # If a donor gives via check, notify when their gift is 30 days past due
  def check(designation_account)
    contacts = []
    designation_account.contacts.financial_partners.each do |contact|
      if contact.direct_deposit?
        unless contact.donations.for(designation_account).since(38.days.ago).first
          contacts << contact
        end
      else
        unless contact.donations.for(designation_account).since((contact.pledge_frequency.to_i + 1).months.ago).first
          contacts << contact
        end
      end
    end
    contacts
  end

  def create_task(account_list, contact)
    task = account_list.tasks.create(subject: task_description(contact), start_at: Time.now, activity_type: _('Call'))
    task.activity_contacts.create(contact_id: contact.id)
    task
  end

  def task_description(contact)
    _("%{contact_name} seems to have missed a gift. Call to follow up.") %
      { contact_name: contact.name }
  end

end
