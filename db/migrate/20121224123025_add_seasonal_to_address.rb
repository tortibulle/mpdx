class AddSeasonalToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :seasonal, :boolean, default: false
    add_column :email_addresses, :location, :string, limit: 50
    add_column :donor_accounts, :donor_type, :string, limit: 20
  end
end
