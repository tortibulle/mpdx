require 'spec_helper'

describe Import do
  before(:each) do
    @tnt_import = double('tnt_import', import_contacts: true, get_lines: OpenStruct.new(:headers => TntImport.required_columns), read_csv: OpenStruct.new(:headers => TntImport.required_columns))
    TntImport.stub(:new).and_return(@tnt_import)
  end

  it "should set 'importing' to false after an import" do
    import = create(:tnt_import, importing: true)
    import.import_contacts
    import.importing.should == false
  end

  it "should send an success email when importing completes" do
    ImportMailer.should_receive(:complete).and_return(OpenStruct.new)
    import = create(:tnt_import)
    import.import_contacts
  end

  it "should send a failure email if there's an error" do
    import = create(:tnt_import)
    @tnt_import.should_receive(:import_contacts).and_raise('foo')

    -> {
      ImportMailer.should_receive(:failed).and_return(OpenStruct.new)
      import.import_contacts
    }.should raise_error

  end
end
