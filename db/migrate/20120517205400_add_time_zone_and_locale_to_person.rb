class AddTimeZoneAndLocaleToPerson < ActiveRecord::Migration
  def change
    add_column :people, :time_zone, :string, limit: 100
    add_column :people, :locale, :string, limit: 10
  end
end
