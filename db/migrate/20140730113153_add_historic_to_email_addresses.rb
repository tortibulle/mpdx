class AddHistoricToEmailAddresses < ActiveRecord::Migration
  def change
    add_column :email_addresses, :historic, :boolean, default: false
  end
end