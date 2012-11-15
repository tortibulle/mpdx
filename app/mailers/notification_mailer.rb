class NotificationMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def notify(account_list, contacts_by_type)
    @contacts_by_type = contacts_by_type

    mail to: account_list.users.collect(&:email),
         subject: _('Giving Notifications from MPDX')
  end
end
