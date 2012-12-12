class AddRemoteIdToContactMethods < ActiveRecord::Migration
  def change
    add_column :addresses, :remote_id, :string
    add_column :email_addresses, :remote_id, :string
    add_column :phone_numbers, :remote_id, :string

    add_index :addresses, :remote_id
    add_index :email_addresses, :remote_id
    add_index :phone_numbers, :remote_id
  end
end
