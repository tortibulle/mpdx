require 'csv_util'

class ReportsController < ApplicationController
  def contributions
    @page_title = _('Contribution Report')

    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
      @end_date = @start_date.end_of_month + 11.months
    else
      @end_date = Date.today.end_of_month
      @start_date = 11.month.ago(@end_date).beginning_of_month
    end

    @raw_donations = current_account_list
      .donations
      .where('donation_date BETWEEN ? AND ?', @start_date, @end_date)
      .select('"donations"."donor_account_id",' \
              'date_trunc(\'month\', "donations"."donation_date"),' \
              'SUM("donations"."tendered_amount") as tendered_amount,' \
              '"donations"."tendered_currency",' \
              '"donor_accounts"."name",' \
              '"contact_donor_accounts"."contact_id" as contact_id,' \
              '"contacts"."status",'\
              '"contacts"."pledge_amount",' \
              '"contacts"."pledge_frequency"'
      )
      .where('contacts.account_list_id' => current_account_list.id)
      .joins(donor_account: [:contacts])
      .group('donations.donor_account_id, ' \
             'date_trunc, ' \
             'tendered_currency, ' \
             'donor_accounts.name, ' \
             'contact_donor_accounts.id, ' \
             'status, ' \
             'pledge_amount, ' \
             'pledge_frequency '
             )
      .reorder('donor_accounts.name')
      .to_a
    @donations = {}
    @sum_row = {}
    @raw_donations.each do |donation|
      @donations[donation.donor_account_id] ||= {
        donor: donation.name, id: donation.contact_id, status: donation.status,
        pledge_amount: donation.pledge_amount,
        pledge_frequency: donation.pledge_frequency,
        amounts: {}, total: 0
      }

      @donations[donation.donor_account_id][:amounts][donation.date_trunc.strftime '%b %y'] = {
        value: donation.tendered_amount,
        currency: donation.tendered_currency
      }

      @donations[donation.donor_account_id][:total] += donation.tendered_amount

      @sum_row[donation.date_trunc.strftime '%b %y'] ||= 0

      @sum_row[donation.date_trunc.strftime '%b %y'] += donation.tendered_amount
    end

    @donations.each do |_key, row|
      if !row[:pledge_frequency].nil? && row[:pledge_frequency].to_f <= 1.0
        # If someone gives monthly and they gave, e.g. $50/month for the past four month
        # and not before that, then assume they are a new ministry partner and their average
        # should be $50/month.
        # Thus we find the first month in the report (from left to right) where they
        # gave a donation and exclude earlier months from the average.
        month_of_first_donation = (0..11).to_a.reverse.find_index {|index|
          !row[:amounts][index.month.ago(@end_date).strftime '%b %y'].nil?
        }
        months_for_average = 12.0 - month_of_first_donation

        # If there was no donation in the current month, then don't count the current
        # month toward the average calculation, as it may be midway through the month
        # and their donation hasn't shown up yet.
        if row[:amounts][0.month.ago(@end_date).strftime '%b %y'].nil?
          months_for_average -= 1.0
        end
      else
        months_for_average = 12.0
      end

      row[:average] = row[:total] / months_for_average
    end

    respond_to do |format|
      format.html
      format.csv do
        html_table = render_to_string formats: [:html], layout: false
        render text: CSVUtil.html_table_to_csv(html_table)
      end
    end
  end
end
