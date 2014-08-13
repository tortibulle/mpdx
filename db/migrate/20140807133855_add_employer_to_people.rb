class AddEmployerToPeople < ActiveRecord::Migration
  def change
    add_column :people, :employer, :string
  end
end