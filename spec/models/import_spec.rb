require 'spec_helper'

describe Import do
  before(:each) do
    @tnt_import = double('tnt_import', import: true, xml: { 'Database' => { 'Tables' => [] } })
    TntImport.stub(:new).and_return(@tnt_import)
  end

  it "should set 'importing' to false after an import" do
    import = create(:tnt_import, importing: true)
    import.send(:import)
    import.importing.should == false
  end

  it 'should send an success email when importing completes' do
    ImportMailer.should_receive(:complete).and_return(OpenStruct.new)
    import = create(:tnt_import)
    import.send(:import)
  end

  it "should send a failure email if there's an error" do
    import = create(:tnt_import)
    @tnt_import.should_receive(:import).and_raise('foo')

    expect {
      ImportMailer.should_receive(:failed).and_return(OpenStruct.new)
      import.send(:import)
    }.to raise_error

  end
end
