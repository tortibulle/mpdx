class CreateCompanyPartnerships < ActiveRecord::Migration
  def change
    create_table :company_partnerships do |t|
      t.belongs_to :account_list
      t.belongs_to :company

      t.timestamps
    end
    add_index :company_partnerships, [:account_list_id, :company_id], name: 'unique_company_account', unique: true
    add_index :company_partnerships, :company_id
  end
end
