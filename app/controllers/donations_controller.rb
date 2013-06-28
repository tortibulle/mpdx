class DonationsController < ApplicationController
  def index
    if params[:contact_id]
      @contact = current_account_list.contacts.where(id: params[:contact_id]).first
      if @contact.donor_account_ids.present?
        @all_donations = current_account_list.donations.where(donor_account_id: donor_account_ids)
      else
        # If the contact isn't linked to a donor account, they're not going to have any donations.
        @all_donations = Donation.where('1 <> 1')
      end
      @donations = @all_donations.page(params[:page])
      setup_chart unless params[:page]
    else
      designation_account_ids = current_account_list.designation_accounts.pluck('designation_accounts.id')
      if params[:start_date]
        @start_date = Date.parse(params[:start_date])
      else
        @start_date = Date.today.beginning_of_month
      end
      @end_date = @start_date.end_of_month
      @donations = current_account_list.donations.where(designation_account_id: designation_account_ids)
                                                 .where("donation_date BETWEEN ? AND ?", @start_date, @end_date)
    end
  end

  private
    def setup_chart
      @by_month = @all_donations.where("donation_date >= ?", 12.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
      @by_month_index = 12.downto(0).collect {|i| i.months.ago.to_date.beginning_of_month}
      @prior_year = @all_donations.where("donation_date >= ? AND donation_date < ?", 24.months.ago.beginning_of_month, 11.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
      @prior_year_index = 24.downto(12).collect {|i| i.months.ago.to_date.beginning_of_month}
    end
end
