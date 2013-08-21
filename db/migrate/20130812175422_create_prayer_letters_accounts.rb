class CreatePrayerLettersAccounts < ActiveRecord::Migration
  def change
    create_table :person_prayer_letters_accounts do |t|
      t.string :token
      t.string :secret
      t.belongs_to :person
      t.boolean :valid_token, default: true, nil: false

      t.timestamps
    end
    add_index :person_prayer_letters_accounts, :person_id
    add_column :contacts, :prayer_letters_id, :string
  end
end
