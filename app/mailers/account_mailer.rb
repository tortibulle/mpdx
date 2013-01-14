class AccountMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def invalid_mailchimp_key(account_list)
    mail to: account_list.users.collect(&:email).compact.collect(&:email),
         subject: _('Mailchimp API Key no longer valid')
  end

end

