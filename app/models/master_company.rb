class MasterCompany < ActiveRecord::Base
  has_many :companies, dependent: :destroy
  has_many :donor_accounts, dependent: :restrict_with_exception

  def self.find_or_create_for_company(company)
    where(name: company.name).first_or_create!
  end
end
