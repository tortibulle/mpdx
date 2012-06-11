class AddNotesSavedAtToContact < ActiveRecord::Migration
  def change
    add_column :contacts, :notes_saved_at, :datetime
  end
end
