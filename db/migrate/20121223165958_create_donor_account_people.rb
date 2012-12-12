class CreateDonorAccountPeople < ActiveRecord::Migration
  def change
    create_table :donor_account_people do |t|
      t.belongs_to :donor_account
      t.belongs_to :person

      t.timestamps
    end
    add_index :donor_account_people, :donor_account_id
    add_index :donor_account_people, :person_id
  end
end
