class CreateDonations < ActiveRecord::Migration
  def change
    create_table :donations do |t|
      t.string :remote_id
      t.belongs_to :donor_account
      t.belongs_to :designation_account
      t.string :motivation
      t.string :payment_method
      t.string :tendered_currency
      t.decimal :tendered_amount, precision: 8, scale: 2
      t.string :currency
      t.decimal :amount, precision: 8, scale: 2
      t.text :memo
      t.date :donation_date

      t.timestamps
    end
    add_index :donations, :donor_account_id
    add_index :donations, [:designation_account_id, :remote_id], name: 'unique_donation_designation', unique: true
  end
end
