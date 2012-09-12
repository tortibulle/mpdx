class ImportMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def complete(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _("Importing your #{import.source} contacts completed"))
  end

  def failed(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _("Importing your #{import.source} contacts failed"))
  end
end
