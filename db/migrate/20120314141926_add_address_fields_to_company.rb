class AddAddressFieldsToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :street, :text

    add_column :companies, :city, :string

    add_column :companies, :state, :string

    add_column :companies, :postal_code, :string

    add_column :companies, :country, :string

    add_column :companies, :phone_number, :string

    change_column :addresses, :street, :text
  end
end
