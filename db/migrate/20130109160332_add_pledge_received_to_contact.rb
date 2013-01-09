class AddPledgeReceivedToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :pledge_received, :boolean, default: false, null: false
    add_column :people, :profession, :string
  end
end
