class AddNameToFacebookAndLinkedin < ActiveRecord::Migration
  def change
    add_column :person_facebook_accounts, :first_name, :string
    add_column :person_facebook_accounts, :last_name, :string
    add_column :person_linkedin_accounts, :first_name, :string
    add_column :person_linkedin_accounts, :last_name, :string
  end
end