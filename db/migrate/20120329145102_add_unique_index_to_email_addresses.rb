class AddUniqueIndexToEmailAddresses < ActiveRecord::Migration
  def change
    add_index :email_addresses, [:email, :person_id], :unique => true
  end
end