class CreateNameMaleRatios < ActiveRecord::Migration
  def change
    create_table :name_male_ratios do |t|
      t.string "name", null: false
      t.float "male_ratio", null: false
      t.timestamps
    end

    add_index :name_male_ratios, :name
  end
end
