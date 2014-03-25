class GoogleIntegrationsController < ApplicationController
  respond_to :html

  def show
    respond_with google_integration
  end

  def update
    google_integration.update_attributes(google_integration_params)

    redirect_to google_integration
  end

  def create
    google_account = current_user.google_accounts.find(params[:google_account_id])

    google_integration = current_account_list.google_integrations.where(google_account_id: google_account.id).first_or_create!

    redirect_to google_integration
  end

  def sync
    google_integration.queue_sync_data(params[:integration])

    redirect_to google_integration, notice: _('MPDX is now synchronizing your tasks with your Google calendar.')
  end

  protected

  def google_integration
    @google_integration ||= current_account_list.google_integrations.find(params[:id])
  end

  def google_integration_params
    params.require(:google_integration).permit(:calendar_integration, :calendar_id, :calendar_name, :new_calendar)
  end
end
