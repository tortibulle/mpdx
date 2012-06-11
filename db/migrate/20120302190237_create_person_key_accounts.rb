class CreatePersonKeyAccounts < ActiveRecord::Migration
  def change
    create_table :person_key_accounts do |t|
      t.belongs_to :person
      t.string :remote_id
      t.string :first_name
      t.string :last_name
      t.string :email
      t.boolean :authenticated, default: false, null: false

      t.timestamps
    end
    add_index :person_key_accounts, :person_id
    add_index :person_key_accounts, [:remote_id, :authenticated], :unique => true

  end
end
