class DonationsController < ApplicationController
  def index
    donor_account_ids = [params[:donor_account_id]]
    if params[:contact_id]
      @contact = current_account_list.contacts.where(id: params[:contact_id]).first
      if @contact.donor_account_ids.present?
        donor_account_ids << @contact.donor_account_ids
      else
        # If the contact isn't linked to a donor account, they're not going to have any donations.
        @all_donations = Donation.where('1 <> 1')
      end
    end
    unless @all_donations
      donor_account_ids.compact!
      #raise donor_account_ids.inspect
      base = donor_account_ids.present? ? current_account_list.donations.where(donor_account_id: donor_account_ids) : Donation
      designation_account_ids = params[:designation_account_id] ? 
                                current_account_list.designation_accounts.where(id: params[:designation_account_id]).pluck('designation_accounts.id') :
                                current_account_list.designation_accounts.pluck('designation_accounts.id')
      @all_donations = base.where(designation_account_id: designation_account_ids)
    end
    @donations = @all_donations.page(params[:page])
    setup_chart unless params[:page]
  end

  private
    def setup_chart
      @by_month = @all_donations.where("donation_date >= ?", 12.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
      @by_month_index = 12.downto(0).collect {|i| i.months.ago.to_date.beginning_of_month}
      @prior_year = @all_donations.where("donation_date >= ? AND donation_date < ?", 24.months.ago.beginning_of_month, 11.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
      @prior_year_index = 24.downto(12).collect {|i| i.months.ago.to_date.beginning_of_month}
    end
end
