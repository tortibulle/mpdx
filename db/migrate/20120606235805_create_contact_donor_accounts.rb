class CreateContactDonorAccounts < ActiveRecord::Migration
  def change
    create_table :contact_donor_accounts do |t|
      t.belongs_to :contact
      t.belongs_to :donor_account

      t.timestamps
    end
    remove_index :contacts, name: :index_contacts_on_donor_account_id_and_account_list_id
    Contact.all.each do |c|
      ContactDonorAccount.create!(contact_id: c.id, donor_account_id: c.donor_account_id)
    end
    remove_column :contacts, :donor_account_id
    add_index :contact_donor_accounts, :contact_id
    add_index :contact_donor_accounts, :donor_account_id
  end
end
