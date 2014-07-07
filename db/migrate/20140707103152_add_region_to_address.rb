class AddRegionToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :region, :string
    add_column :addresses, :metro_area, :string
  end
end