class CreateNicknames < ActiveRecord::Migration
  def change
    create_table :nicknames do |t|
      t.string "name"
      t.string "nickname"
      t.string "source"
      t.integer "num_merges"
      t.timestamps
    end

    add_index :nicknames, :name
    add_index :nicknames, :nickname
    add_index :nicknames, [:name, :nickname], unique: true
  end
end
