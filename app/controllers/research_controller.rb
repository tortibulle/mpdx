class ResearchController < ApplicationController
  def index
  end

  def search
    @contact = current_account_list.contacts.find(params[:id])
    account_numbers = @contact.donor_accounts.pluck(:account_number)
    @donor_data = if @contact.donor_accounts.present?
                    SiebelDonations::Donor.find(ids: account_numbers.join(','))
                  else
                    []
                  end

    @other_contacts = Contact.joins(:donor_accounts)
      .where('donor_accounts.account_number' => account_numbers)
      .where.not('contacts.id' => @contact.id)
  end
end
