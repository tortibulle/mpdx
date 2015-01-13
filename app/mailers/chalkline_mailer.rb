class ChalklineMailer < ActionMailer::Base
  TIME_ZONE = 'Central Time (US & Canada)'
  default from: 'MPDX <support@mpdx.org>', to: APP_CONFIG['chalkline_newsletter_email']

  def mailing_list(account_list)
    @name = account_list.users_combined_name
    user_emails = account_list.user_emails_with_names
    time_formatted = Time.now.in_time_zone(TIME_ZONE).strftime('%Y%m%d %l%M%P')
    filename = "#{@name} #{time_formatted}.csv".gsub(/\s+/, '_').downcase
    attachments[filename] = { mime_type: 'text/csv',  content: account_list.physical_newsletter_csv }
    mail subject: "MPDX List: #{@name}", cc: user_emails, reply_to: user_emails
  end
end
