class CreateImports < ActiveRecord::Migration
  def change
    create_table :imports do |t|
      t.belongs_to :account_list
      t.string :source
      t.string :file
      t.boolean :importing

      t.timestamps
    end
    add_index :imports, :account_list_id
  end
end
