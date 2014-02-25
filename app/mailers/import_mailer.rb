class ImportMailer < ActionMailer::Base
  default from: "support@mpdx.org"

  def complete(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _('[MPDX] Importing your %{source} contacts completed').localize % { source: import.source })
  end

  def failed(import)
    user = import.user
    @import = import
    I18n.locale = user.locale || 'en'

    mail(to: user.email, subject: _('[MPDX] Importing your %{source} contacts failed').localize % { source: import.source })
  end

  def credentials_error(account)
    user = account.person
    @account = account

    mail(to: user.email, subject: _('[MPDX] Your username and password for %{source} are invalid').localize % { source: account.organization.name })
  end
end
