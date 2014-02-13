# This class stubs out data server stuff for orgs that don't have anything for us to download
require_dependency 'data_server'
class OfflineOrg < DataServer
  def import_all(date_from = nil)
    # Do nothing
  end

  def self.requires_username_and_password?
    false
  end
end