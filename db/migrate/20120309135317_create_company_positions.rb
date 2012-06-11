class CreateCompanyPositions < ActiveRecord::Migration
  def change
    create_table :company_positions do |t|
      t.belongs_to :person, null: false
      t.belongs_to :company, null: false
      t.date :start_date
      t.date :end_date
      t.string :position

      t.timestamps
    end
    add_index :company_positions, :person_id
    add_index :company_positions, :company_id
    add_index :company_positions, :start_date
  end
end