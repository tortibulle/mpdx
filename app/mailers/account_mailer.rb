class AccountMailer < ActionMailer::Base
  default from: 'support@mpdx.org'

  def invalid_mailchimp_key(account_list)
    mail to: account_list.users.map(&:email).compact.map(&:email),
         subject: _('Mailchimp API Key no longer valid')
  end

  def mailchimp_required_merge_field(account_list)
    mail to: account_list.users.map(&:email).compact.map(&:email),
         subject: _('Mailchimp List is requiring an additional merge field')
  end

  def prayer_letters_invalid_token(account_list)
    mail to: account_list.users.map(&:email).compact.map(&:email),
         subject: _('prayerletters.com account needs to be refreshed')
  end
end
