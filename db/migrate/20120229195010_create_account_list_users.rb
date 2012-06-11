class CreateAccountListUsers < ActiveRecord::Migration
  def change
    create_table :account_list_users do |t|
      t.belongs_to :user
      t.belongs_to :account_list

      t.timestamps
    end
    add_index :account_list_users, [:user_id, :account_list_id], unique: true
    add_index :account_list_users, :account_list_id
  end
end
