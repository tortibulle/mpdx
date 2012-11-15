class NotificationMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def notify(account_list, notifications_by_type)
    @notifications_by_type = notifications_by_type

    mail to: account_list.users.collect(&:email).compact.collect(&:email),
         subject: _('Giving Notifications from MPDX')
  end
end
