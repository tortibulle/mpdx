class CreatePersonLinkedinAccounts < ActiveRecord::Migration
  def change
    create_table :person_linkedin_accounts do |t|
      t.integer :person_id, null: false
      t.string :remote_id, null: false
      t.string :token
      t.string :secret
      t.datetime :token_expires_at

      t.timestamps
    end
    add_index :person_linkedin_accounts, [:person_id, :remote_id], unique: true
    add_index :person_linkedin_accounts, :remote_id

  end
end
