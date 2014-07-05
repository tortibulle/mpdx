class HomeController < ApplicationController
  skip_before_action :ensure_login, only: [:login, :privacy]

  def index
    @page_title = _('Dashboard')
  end

  def connect
    if !request.xhr?
      redirect_to '/#dash-connect' and return
    end
  end

  def cultivate
    if !request.xhr?
      redirect_to '/#dash-cultivate' and return
    end
  end

  def care
    if !request.xhr?
      redirect_to '/#dash-care' and return
    end
  end

  def progress
    if !request.xhr?
      redirect_to '/#dash-progress' and return
    end

    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = Date.today.beginning_of_week
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
