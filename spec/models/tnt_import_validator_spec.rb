require 'spec_helper'

describe TntImportValidator do
  it 'should not be valid if missing required columns' do
    import = build(:tnt_import, file: File.new(Rails.root.join('spec/fixtures/tnt/tnt_export_bad.csv')))
    import.valid?.should be_false
  end

  it 'should be valid if it has all the required columns' do
    import = build(:tnt_import)
    import.valid?.should == true
  end

end
