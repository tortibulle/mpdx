class CreateMasterCompanies < ActiveRecord::Migration
  def change
    create_table :master_companies do |t|
      t.string :name
      
      t.timestamps
    end
    add_column :companies, :master_company_id, :integer
    add_column :donor_accounts, :master_company_id, :integer
  end
end