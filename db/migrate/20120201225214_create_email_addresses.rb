class CreateEmailAddresses < ActiveRecord::Migration
  def change
    create_table :email_addresses do |t|
      t.belongs_to :person
      t.string :email, null: false
      t.boolean :primary, default: false

      t.timestamps
    end
    add_index :email_addresses, :person_id
  end
end
