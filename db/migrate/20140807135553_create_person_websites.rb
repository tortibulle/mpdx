class CreatePersonWebsites < ActiveRecord::Migration
  def change
    create_table :person_websites do |t|
      t.belongs_to :person
      t.string :url
      t.boolean :primary, default: false

      t.timestamps
    end
    add_index :person_websites, :person_id
  end
end
