class CreateActivityComments < ActiveRecord::Migration
  def change
    create_table :activity_comments do |t|
      t.belongs_to :activity
      t.belongs_to :person
      t.text :body

      t.timestamps
    end

    add_column :activities, :activity_comments_count, :integer, default: 0

    add_index :activity_comments, :activity_id
    add_index :activity_comments, :person_id
  end
end
