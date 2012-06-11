class MakeStreetATextField < ActiveRecord::Migration
  def up
    change_column :addresses, :street1, :text
    rename_column :addresses, :street1, :street
    remove_column :addresses, :street2
    remove_column :addresses, :street3
    add_column :addresses, :primary_mailing_address, :boolean, default: false
    add_column :addresses, :address_type, :string
  end

  def down
    remove_column :addresses, :address_type
    remove_column :addresses, :primary_mailing_address
    add_column :addresses, :street3, :string
    add_column :addresses, :street2, :string
    rename_column :addresses, :street, :street1
    change_column :addresses, :street1, :string
  end
end
