class GoogleIntegrationsController < ApplicationController
  respond_to :html, :js

  def show
    respond_with google_integration
  end

  def update
    google_integration.update_attributes(google_integration_params)

    respond_to do |format|
      format.html { redirect_to google_integration }
      format.js { render nothing: true }
    end
  rescue Person::GoogleAccount::MissingRefreshToken
    missing_refresh_token
  end

  def create
    google_account = current_user.google_accounts.find(params[:google_account_id])

    google_integration = current_account_list.google_integrations.where(google_account_id: google_account.id).first_or_create!

    redirect_to google_integration
  end

  def sync
    google_integration.queue_sync_data(params[:integration])

    notice = ''
    case params[:integration]
    when 'calendar'
      notice = _('MPDX is now synchronizing your tasks with your Google calendar.')
    when 'email'
      notice = _('MPDX is now synchronizing your history with your Gmail account.')
    end

    redirect_to google_integration, notice: notice
  end

  protected

  def google_integration
    @google_integration ||= current_account_list.google_integrations.find(params[:id])
  end

  def google_integration_params
    params.require(:google_integration).permit([:calendar_integration, { calendar_integrations: [] }, :calendar_id, :calendar_name, :new_calendar, :email_integration])
  end

  def missing_refresh_token
    redirect_to google_integration_path(google_integration), alert: "<a href=\"#{new_account_path(provider: :google, redirect: google_integration_path(google_integration))}\">#{_('The link to your google account needs to be resynced. Click here to re-connect to google.')}</a>"
  end
end
