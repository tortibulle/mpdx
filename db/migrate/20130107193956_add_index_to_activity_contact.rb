class AddIndexToActivityContact < ActiveRecord::Migration
  def change
    add_index :activity_contacts, [:contact_id, :activity_id], unique: true
  end
end
