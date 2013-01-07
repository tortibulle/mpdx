class Company < ActiveRecord::Base
  has_many :company_positions, dependent: :destroy
  has_many :people, through: :company_positions
  has_many :company_partnerships, dependent: :destroy
  has_many :account_lists, through: :company_partnerships
  belongs_to :master_company

  before_create :find_master_company
  after_destroy :clean_up_master_company

  def to_s() name; end

  private
  def find_master_company
    unless master_company_id
      self.master_company_id = MasterCompany.find_or_create_for_company(self).id
    end
  end

  def clean_up_master_company
    self.master_company.destroy if self.master_company.companies.blank?
  end
end
