class CreatePersonFacebookAccounts < ActiveRecord::Migration
  def change
    create_table :person_facebook_accounts do |t|
      t.integer :person_id, null: false
      t.column :remote_id, :bigint, null: false
      t.string :token
      t.datetime :token_expires_at

      t.timestamps
    end
    add_index :person_facebook_accounts, [:person_id, :remote_id], unique: true
    add_index :person_facebook_accounts, :remote_id

  end
end
