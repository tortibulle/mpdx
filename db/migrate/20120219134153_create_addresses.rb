class CreateAddresses < ActiveRecord::Migration
  def change
    create_table :addresses do |t|
      t.belongs_to :person
      t.string :street1
      t.string :street2
      t.string :street3
      t.string :city
      t.string :state
      t.string :country
      t.string :postal_code
      t.boolean :seasonal, default: true
      t.string :location
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
    add_index :addresses, :person_id
  end
end
