class Organization < ActiveRecord::Base
  has_many :designation_accounts, dependent: :destroy
  has_many :designation_profiles, dependent: :destroy
  has_many :donor_accounts, dependent: :destroy
  has_many :master_person_sources, dependent: :destroy
  has_many :master_people, through: :master_person_sources

  validates :name, :query_ini_url, presence: true
  scope :active, where('addresses_url is not null')

  attr_accessible :name

  def to_s() name; end

  def api(org_account)
    api_class.constantize.new(org_account)
  end

end
