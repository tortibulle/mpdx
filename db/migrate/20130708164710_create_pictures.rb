class CreatePictures < ActiveRecord::Migration
  def change
    create_table :pictures do |t|
      t.integer :picture_of_id
      t.string :picture_of_type
      t.string :image
      t.boolean :primary, default: false, null: false

      t.timestamps
    end

    add_index :pictures, [:picture_of_id, :picture_of_type], name: 'picture_of'
  end
end
