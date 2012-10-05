class CreateMailChimpAccounts < ActiveRecord::Migration
  def change
    create_table :mail_chimp_accounts do |t|
      t.string :api_key
      t.boolean :active, default: false
      t.integer :grouping_id
      t.string :primary_list_id
      t.integer :account_list_id

      t.timestamps
    end

    add_index :mail_chimp_accounts, :account_list_id
  end
end
