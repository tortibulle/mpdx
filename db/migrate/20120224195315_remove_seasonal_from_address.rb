class RemoveSeasonalFromAddress < ActiveRecord::Migration
  def up
    remove_column :addresses, :seasonal
  end

  def down
    add_column :addresses, :seasonal, boolean: true
  end
end
