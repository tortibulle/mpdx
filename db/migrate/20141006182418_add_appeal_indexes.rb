class AddAppealIndexes < ActiveRecord::Migration
  def change
    add_index :appeal_contacts, :appeal_id
    add_index :donations, :appeal_id
  end
end
