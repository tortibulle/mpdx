class AddPublicUrlToPersonLinkedinAccounts < ActiveRecord::Migration
  def change
    add_column :person_linkedin_accounts, :public_url, :string
  end
end
