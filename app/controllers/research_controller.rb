class ResearchController < ApplicationController
  def index
  end

  def search
    @contact = current_account_list.contacts.find(params[:id])
    @donor_data = if @contact.donor_accounts.present?
                   SiebelDonations::Donor.find(ids: @contact.donor_accounts.collect(&:account_number).join(','))
                 else
                   []
                 end
  end
end