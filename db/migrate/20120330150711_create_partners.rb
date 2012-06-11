class CreatePartners < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.string :name
      t.belongs_to :donor_account
      t.belongs_to :account_list

      t.timestamps
    end
    add_index :contacts, [:donor_account_id, :account_list_id], unique: true
    add_index :contacts, :account_list_id

    remove_column :people, :account_list_id

    # Make address polymorphic
    add_column :addresses, :addressable_type, :string
    rename_column :addresses, :person_id, :addressable_id
    ActiveRecord::Base.connection.update("update addresses set addressable_type = 'Person'")
  end
end
