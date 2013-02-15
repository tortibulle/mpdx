class HelpRequestMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.help_request_mailer.email.subject
  #
  def email(help_request)
    @help_request = help_request

    mail to: "support@mpdx.org", subject: help_request.request_type,
         from: "#{help_request.name} <#{help_request.email}>"
  end
end
