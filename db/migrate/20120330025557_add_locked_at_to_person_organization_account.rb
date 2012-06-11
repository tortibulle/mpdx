class AddLockedAtToPersonOrganizationAccount < ActiveRecord::Migration
  def change
    add_column :person_organization_accounts, :locked_at, :datetime

  end
end
