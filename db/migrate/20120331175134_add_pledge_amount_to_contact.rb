class AddPledgeAmountToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :pledge_amount, :decimal, precision: 8, scale: 2

  end
end
