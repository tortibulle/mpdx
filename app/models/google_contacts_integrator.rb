# -> Get a list of all "Active" contacts
# -> Go through each contact
# ---> If they already have a single Google contact from that G account, just compare and sync on that contact
# ---> If they have multiple Google contacts from that G account
#        - decide which one is primary for MPDX purposes, maybe the one with the most information?
#        - update a column to represent the primary Google contact for that person and Google account
#        - compare and sync that contact
# ---> (If the contact you are trying to sync doesn't exist, search for a different Google contact for that person)
# ---> OK, so for a person that doesn't have a matching google_contacts entry, search Google contacts for a matching
#      name / address / phone / email and associate with that Contact if possible
# ---> Otherwise, create a new Google contact and associate with it

class GoogleContactsIntegrator
  attr_accessor :client

  def initialize(google_integration)
    @google_integration = google_integration
    @google_account = google_integration.google_account
    @client = @google_account.client
  end

  def sync_contacts
  end
end
