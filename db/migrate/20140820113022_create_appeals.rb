class CreateAppeals < ActiveRecord::Migration
  def change
    create_table :appeals do |t|
      t.string :name
      t.belongs_to :account_list
      t.decimal :amount, precision: 8, scale: 2
      t.text :description
      t.date :end_date

      t.timestamps
    end
    add_index :appeals, :account_list_id
  end
end
