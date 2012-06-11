class MoveOrganizationAccountUnderPerson < ActiveRecord::Migration
  def up
    rename_table :organization_accounts, :person_organization_accounts
    rename_column :person_organization_accounts, :user_id, :person_id
    add_column :person_organization_accounts, :remote_id, :string
    add_column :person_organization_accounts, :authenticated, :boolean, default: false, null: false
    add_column :person_organization_accounts, :valid_credentials, :boolean, default: false, null: false
    add_column :organizations, :api_class, :string
  end

  def down
    remove_column :organizations, :api_class
    remove_column :person_organization_accounts, :valid_credentials
    remove_column :person_organization_accounts, :authenticated
    remove_column :person_organization_accounts, :remote_id
    rename_column :person_organization_accounts, :person_id, :user_id
    rename_table :person_organization_accounts, :organization_accounts
  end
end