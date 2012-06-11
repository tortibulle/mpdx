class AddTokenToPersonOrganizationAccount < ActiveRecord::Migration
  def change
    add_column :person_organization_accounts, :token, :string
  end
end
