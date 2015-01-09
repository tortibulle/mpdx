class AddAppealAmountToDonations < ActiveRecord::Migration
  def change
    add_column :donations, :appeal_amount, :decimal, precision: 8, scale: 2
  end
end
