class DonationsController < ApplicationController
  before_filter :get_donation, only: [:edit, :destroy, :update]
  before_filter :get_contact
  before_filter :get_donor_accounts, only: [:edit, :new]

  def index
    if @contact
      if @contact.donor_account_ids.present?
        @all_donations = current_account_list.donations.where(donor_account_id: @contact.donor_account_ids)
      else
        # If the contact isn't linked to a donor account, they're not going to have any donations.
        @all_donations = Donation.where('1 <> 1')
      end
      @donations = @all_donations.page(params[:page])
      setup_chart unless params[:page]
    else
      @page_title = _('Donations')

      if params[:start_date]
        @start_date = Date.parse(params[:start_date])
      else
        @start_date = Date.today.beginning_of_month
      end
      @end_date = @start_date.end_of_month
      @donations = current_account_list.donations.where("donation_date BETWEEN ? AND ?", @start_date, @end_date)
                                                 .where("contacts.account_list_id" => current_account_list.id)
                                                 .includes(donor_account: :contacts)
    end
  end

  def edit
  end

  def new
    if !request.xhr?
      redirect_to donations_path and return
    end

    @donation = current_account_list.donations.new(designation_account_id: current_account_list.designation_accounts.first.try(:id))
  end

  def create
    @donation = current_account_list.donations.new(donation_params)

    unless @donation.save
      get_donor_accounts
      render action: :new
    end
  end

  def update
    unless @donation.update_attributes(donation_params)
      get_donor_accounts
      render action: :edit
    end
  end

  def destroy
    @donation.destroy
  end

  def contribution_report
    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
      @end_date = @start_date.end_of_month + 11.months
    else
      @end_date = Date.today.end_of_month
      @start_date = 11.month.ago(@end_date).beginning_of_month
    end
    @raw_donations = current_account_list.
      donations.
      where("donation_date BETWEEN ? AND ?", @start_date, @end_date).
      select('"donations"."donor_account_id",' +
             'date_trunc(\'month\', "donations"."donation_date"),' +
             'SUM("donations"."amount") as amount'
            ).
      group('donor_account_id, date_trunc, donation_date').
      order('donor_account_id, date_trunc').
      all
    @donations = {}
    @sum_row = {}
    @raw_donations.each do |donation|
      if @donations[donation.donor_account_id].nil?
        @donations[donation.donor_account_id] = { donor: donation.donor_account,
                                                  amounts: {} }
      end
      @donations[donation.donor_account_id]\
                [:amounts]\
                [donation.date_trunc.strftime '%b %y'] = donation.amount
      if @sum_row[donation.date_trunc.strftime '%b %y'].nil?
        @sum_row[donation.date_trunc.strftime '%b %y'] = 0
      end
      @sum_row[donation.date_trunc.strftime '%b %y'] += donation.amount
    end
  end

  private

  def setup_chart
    @by_month = @all_donations.where("donation_date >= ?", 12.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
    @by_month_index = 12.downto(0).collect {|i| i.months.ago.to_date.beginning_of_month}
    @prior_year = @all_donations.where("donation_date >= ? AND donation_date < ?", 24.months.ago.beginning_of_month, 11.months.ago.beginning_of_month).group_by {|r| r.donation_date.beginning_of_month}
    @prior_year_index = 24.downto(12).collect {|i| i.months.ago.to_date.beginning_of_month}
  end

  def get_donation
    @donation = current_account_list.donations.find(params[:id])
  end

  def donation_params
    params.require(:donation).permit("donation_date(1i)", "donation_date(2i)", "donation_date(3i)", "tendered_amount", "donor_account_id", "designation_account_id")
  end

  def get_contact
    @contact = current_account_list.contacts.where(id: params[:contact_id]).first if params[:contact_id]
  end

  def get_donor_accounts
    @donor_accounts = []
    if @contact
      @contact.donor_accounts.each do |da|
        @donor_accounts << ["#{@contact.name} (#{da.account_number})", da.id]
      end
    else
      current_account_list.contacts.active.joins(:donor_accounts).includes(:donor_accounts).each do |c|
        c.donor_accounts.each do |da|
          @donor_accounts << ["#{c.name} (#{da.account_number})", da.id]
        end
      end
      @donor_accounts.sort_by! { |da| da.first }
    end
  end
end
