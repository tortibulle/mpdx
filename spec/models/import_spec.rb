require 'spec_helper'

describe Import do
  it "should set 'importing' to false after an import" do
    TntImport.stub(:new).and_return(double('tnt_import', import_contacts: true))
    import = create(:tnt_import, importing: true)
    import.import_contacts
    import.importing.should == false
  end
end
