require 'spec_helper'

describe TntImport do
  describe 'import_contacts' do
    before do
      @import = TntImport.new(create(:tnt_import))
    end

    it 'should add contact to account list' do
      @import.stub(:add_or_update_donor_accounts).and_return([[create(:donor_account)], create(:contact)])
      @import.import_contacts
    end
  end

end
