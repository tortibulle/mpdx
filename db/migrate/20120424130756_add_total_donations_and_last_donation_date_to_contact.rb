class AddTotalDonationsAndLastDonationDateToContact < ActiveRecord::Migration
  def change
    add_column :donor_accounts, :total_donations, :decimal, precision: 10, scale: 2
    add_column :donor_accounts, :last_donation_date, :date
    add_column :donor_accounts, :first_donation_date, :date

    add_index :donor_accounts, :total_donations
    add_index :donor_accounts, :last_donation_date

    add_column :contacts, :total_donations, :decimal, precision: 10, scale: 2
    add_column :contacts, :last_donation_date, :date
    add_column :contacts, :first_donation_date, :date

    add_index :contacts, :total_donations
    add_index :contacts, :last_donation_date

    # update donor_accounts da set da.total_donations = (select sum(amount) from donations d where d.donor_account_id = da.id)
    # update donor_accounts da set da.last_donation_date = (select max(donation_date) from donations d where d.donor_account_id = da.id)
    # update donor_accounts da set da.first_donation_date = (select min(donation_date) from donations d where d.donor_account_id = da.id)

    AccountList.all.each do |a|
      a.contacts.each do |c|
        if c.donor_account_id
          designation_account_ids = a.designation_accounts.pluck('designation_accounts.id')
          donations = Donation.where(donor_account_id: c.donor_account_id, designation_account_id: designation_account_ids)
          c.update_column(:total_donations, donations.sum(:amount))
          c.update_column(:last_donation_date, donations.maximum(:donation_date))
          c.update_column(:first_donation_date, donations.minimum(:donation_date))
        end
      end
    end


  end
end
