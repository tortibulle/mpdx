class CreateAccountListEntries < ActiveRecord::Migration
  def change
    create_table :account_list_entries do |t|
      t.belongs_to :account_list
      t.belongs_to :designation_account

      t.timestamps
    end
    add_index :account_list_entries, [:account_list_id, :designation_account_id], name: 'unique_account', unique: true
    add_index :account_list_entries, :designation_account_id
  end
end
