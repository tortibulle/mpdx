class AddFieldsToContact < ActiveRecord::Migration
  def change
    change_table :contacts, bulk: true do |t|
      t.string :full_name
      t.string :greeting
      t.string :website, limit: 1000
      t.integer :pledge_frequency
      t.date :pledge_start_date
      t.boolean :deceased, default: false, null: false
      t.date :next_ask
      t.boolean :never_ask, default: false, null: false
      t.integer :likely_to_give
      t.string :church_name
      t.string :send_newsletter
      t.boolean :direct_deposit, default: false, null: false
      t.boolean :magazine, default: false, null: false
      t.date :last_activity
      t.date :last_appointment
      t.date :last_letter
      t.date :last_phone_call
      t.date :last_pre_call
      t.date :last_thank
    end
  end
end
