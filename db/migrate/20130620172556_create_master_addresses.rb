class CreateMasterAddresses < ActiveRecord::Migration
  def change
    create_table :master_addresses do |t|
      t.text :street
      t.string :city
      t.string :state
      t.string :country
      t.string :postal_code
      t.boolean :verified, :boolean, default: false, null: false
      t.text :smarty_response

      t.timestamps
    end

    add_column :addresses, :master_address_id, :integer
    add_column :addresses, :verified, :boolean, default: false, null: false

    add_index :master_addresses, [:street, :city, :state, :country, :postal_code], name: 'all_fields'
    add_index :addresses, :master_address_id
  end
end
