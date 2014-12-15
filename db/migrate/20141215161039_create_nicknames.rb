class CreateNicknames < ActiveRecord::Migration
  def change
    create_table :nicknames do |t|
      t.string "name", null: false
      t.string "nickname", null: false
      t.string "source"
      t.integer "num_merges", default: 0
      t.boolean  "suggest_duplicates", default: false
      t.timestamps
    end

    add_index :nicknames, :name
    add_index :nicknames, :nickname
    add_index :nicknames, [:name, :nickname], unique: true
  end
end
