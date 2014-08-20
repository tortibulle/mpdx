class CreateAppeals < ActiveRecord::Migration
  def change
    create_table :appeals do |t|
      t.string :name
      t.decimal :amount, precision: 8, scale: 2
      t.text :description
      t.date :end_date

      t.timestamps
    end
    add_index :appeals
  end
end
