class GoogleEmailIntegrator
  attr_accessor :client

  def initialize(google_integration)
    @google_integration = google_integration
    @google_account = google_integration.google_account
  end

  def sync_mail
    if @google_integration.email_integration?
      @google_account.import_emails(@google_integration.account_list)
    end
  end
end
