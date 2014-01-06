class ImportMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def complete(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _('Importing your %{source} contacts completed').localize % { source: import.source })
  end

  def failed(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _('Importing your %{source} contacts failed').localize % { source: import.source })
  end
end
