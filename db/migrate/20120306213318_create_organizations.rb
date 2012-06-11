class CreateOrganizations < ActiveRecord::Migration
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :query_ini_url
      t.string :iso3166
      t.string :minimum_gift_date
      t.string :logo, length: 2000
      t.string :code
      t.boolean :query_authentication
      t.string :account_help_url, length: 2000
      t.string :abbreviation
      t.string :org_help_email
      t.string :org_help_url, length: 2000
      t.string :org_help_url_description, length: 2000
      t.text :org_help_other
      t.string :request_profile_url, length: 2000
      t.string :staff_portal_url, length: 2000
      t.string :default_currency_code
      t.boolean :allow_passive_auth
      t.string :account_balance_url, length: 2000
      t.string :account_balance_params
      t.string :donations_url, length: 2000
      t.string :donations_params, length: 2000
      t.string :addresses_url, length: 2000
      t.string :addresses_params, length: 2000
      t.string :addresses_by_personids_url, length: 2000
      t.string :addresses_by_personids_params, length: 2000
      t.string :profiles_url, length: 2000
      t.string :profiles_params, length: 2000
      t.string :redirect_query_ini, length: 2000

      t.timestamps
    end
    rename_column :designation_accounts, :account_source, :profile
    add_column :designation_accounts, :organization_id, :integer
    add_index :designation_accounts, :organization_id
    add_index :organizations, :query_ini_url, :unique => true
  end
end
