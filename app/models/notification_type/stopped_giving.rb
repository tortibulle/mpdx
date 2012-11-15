class NotificationType::StoppedGiving < NotificationType

  # If the donor uses direct deposit, notify if it's been more than 31 + 7 days
  # (the extra week is to allow for a delay in the donation system)
  # If a donor gives via check, notify when their gift is 30 days past due
  def process(designation_account)
    designation_account.contacts.financial_partners.each do |contact|
      if contact.direct_deposit?
        unless contact.donations.for(designation_account).since(38.days.ago).first
          add_notification(type, designation_account)
        end
      else
        unless contact.donations.for(designation_account).since((contact.pledge_frequency.to_i + 1).months.ago).first
          add_notification(type, designation_account)
        end
      end
    end
  end

end
