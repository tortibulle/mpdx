require 'spec_helper'

describe Company do
  it 'should return the company name for to_s' do
    Company.new(name: 'foo').to_s.should == 'foo'
  end

  it 'should delete master_company on destroy if there are no other companies for that master' do
    company = FactoryGirl.create(:company)
    -> {
      company.destroy
    }.should change(MasterCompany, :count).from(1).to(0)
  end

  it 'should NOT delete master_company on destroy if there are other companies for that master' do
    company = FactoryGirl.create(:company)
    FactoryGirl.create(:company, master_company: company.master_company)
    -> {
      company.destroy
    }.should_not change(MasterCompany, :count)
  end

end
