class MakeNameMaleRatiosNameUnique < ActiveRecord::Migration
  def change
    remove_index :name_male_ratios, :name
    add_index :name_male_ratios, :name, unique: true
  end
end
