class CreateAccountLists < ActiveRecord::Migration
  def change
    create_table :account_lists do |t|
      t.string :name
      t.integer :creator_id

      t.timestamps
    end
    add_index :account_lists, :creator_id
    remove_column :people, :designation_account_id
    add_column :people, :account_list_id, :integer
  end
end
