class DeviseCreateUsers < ActiveRecord::Migration
  def change
    create_table(:people) do |t|
      t.string :guid
      t.string :first_name, :null => false
      t.string :legal_first_name
      t.string :last_name
      t.integer :birthday_month
      t.integer :birthday_year
      t.integer :birthday_day
      t.integer :anniversary_month
      t.integer :anniversary_year
      t.integer :anniversary_day
      t.string :title
      t.string :suffix
      t.string :gender
      t.string :marital_status
      t.text :preferences
      t.integer :designation_account_id

      ## Trackable
      t.integer  :sign_in_count, :default => 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.timestamps
    end

    add_index :people, :guid,                :unique => true
    add_index :people, :first_name
    add_index :people, :last_name
    add_index :people, :designation_account_id
  end
end
