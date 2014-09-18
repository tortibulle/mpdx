class CreateAppealDonations < ActiveRecord::Migration
  def change
    create_table :appeal_donations do |t|
      t.belongs_to :appeal
      t.belongs_to :donation

      t.timestamps
    end
    add_index :appeal_donations, [:appeal_id, :donation_id]
    add_index :appeal_donations, :donation_id
  end
end
