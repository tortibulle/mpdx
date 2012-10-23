require 'spec_helper'

describe TntImport do
  describe '#import_contacts' do
    let(:tnt_import) { create(:tnt_import) }
    let(:import) { TntImport.new(tnt_import) }
    let(:contact) { create(:contact) }

    it 'adds a contact to account list' do
      import.stub(:add_or_update_donor_accounts).and_return([[create(:donor_account)], contact])
      import.import_contacts
    end

    it "imports a phone number for a person" do
      line = import.read_csv(tnt_import.file.file.file).first
      person = Person.new
      person = import.send(:update_person_attributes, person, line, '')
      person.phone_numbers.length.should == 4
    end
  end

end
