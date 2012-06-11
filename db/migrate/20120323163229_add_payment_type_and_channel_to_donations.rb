class AddPaymentTypeAndChannelToDonations < ActiveRecord::Migration
  def change
    add_column :donations, :payment_type, :string

    add_column :donations, :channel, :string

  end
end
