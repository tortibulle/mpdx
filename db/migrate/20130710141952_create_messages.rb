class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.belongs_to :from
      t.belongs_to :to
      t.string :subject
      t.text :body
      t.datetime :sent_at
      t.string :source
      t.string :remote_id
      t.belongs_to :contact
      t.belongs_to :account_list

      t.timestamps
    end
    add_index :messages, :from_id
    add_index :messages, :to_id
    add_index :messages, :contact_id
    add_index :messages, :account_list_id
  end
end
