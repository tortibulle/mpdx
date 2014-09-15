require 'spec_helper'

describe MasterCompany do
  it 'should find an existing master company' do
    company = FactoryGirl.create(:company)
    expect {
      MasterCompany.find_or_create_for_company(FactoryGirl.build(:company)).should == company.master_company
    }.to_not change(MasterCompany, :count)
  end

  it 'should create a new master company' do
    expect {
      MasterCompany.find_or_create_for_company(FactoryGirl.build(:company))
    }.to change(MasterCompany, :count)
  end
end
