class CreatePersonTwitterAccounts < ActiveRecord::Migration
  def change
    create_table :person_twitter_accounts do |t|
      t.integer :person_id, null: false
      t.column :remote_id, :bigint, null: false
      t.string :screen_name
      t.string :token
      t.string :secret

      t.timestamps
    end
    add_index :person_twitter_accounts, [:person_id, :remote_id], unique: true
    add_index :person_twitter_accounts, :remote_id
  end
end
