class FacebookImportMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def complete(user)
    @template = "#{ActionMailer::Base::template_root}/facebook_import_mailer/complete.#{user.locale || 'en'}"

    mail(to: email, subject: _('Importing your facebook friends'), template_name: @template)
  end
end
