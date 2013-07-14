class HomeController < ApplicationController
  skip_before_filter :ensure_login, only: [:login, :privacy]

  def index
    @page_title = _('Dashboard')
  end

  def connect
  end

  def care
  end

  def progress
    if !request.xhr?
      redirect_to '/'
    end

    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = 1.week.ago.beginning_of_week
    end
    @end_date = @start_date.end_of_week
  end

  def login
    render layout: false
  end

  def privacy
    render layout: false
  end

  def change_account_list
    session[:current_account_list_id] = params[:id] if current_user.account_lists.pluck('account_lists.id').include?(params[:id].to_i)
    redirect_to '/'
  end

  def download_data_check
    render text: current_user.organization_accounts.any?(&:downloading?)
  end

end
