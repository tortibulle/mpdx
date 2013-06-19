class HomeController < ApplicationController
  skip_before_filter :ensure_login, only: [:login, :privacy]

  def index
    @page_title = _('Dashboard')

    @tasks = current_account_list.tasks.uncompleted.includes(:contacts).limit(6)
  end

  def care
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

  def js
    render layout: "js"
  end

end
