class GoogleIntegrationsController < ApplicationController
  def show
  end

  def update
    if google_integration.update_attributes(google_integration_params)
      redirect_options = {}
      if google_integration.contacts_integration
        # Start the Google Contacts sync after its first enabled since its not queued on a schedule but only when contacts
        # are changed or when the user clicks "Sync Now". This way if they don't update a contact or click "Sync Now"
        # for a while the sync will still get started.
        google_integration.queue_sync_data('contacts')
        redirect_options[:notice] = _('MPDX is now synchronizing your active contacts with your Google Contacts.')
      end

      respond_to do |format|
        format.html { redirect_to google_integration, redirect_options }
        format.js { render nothing: true }
      end
    else
      missing_refresh_token
    end
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
    when 'contacts'
      notice = _('MPDX is now synchronizing your active contacts with your Google Contacts.')
    end

    redirect_to google_integration, notice: notice
  end

  protected

  def google_integration
    @google_integration ||= current_account_list.google_integrations.find(params[:id])
  end

  def google_integration_params
    params.require(:google_integration).permit([:calendar_integration, { calendar_integrations: [] }, :calendar_id,
                                                :calendar_name, :new_calendar, :email_integration, :contacts_integration])
  end

  def missing_refresh_token
    alert_notice = _('The link to your google account needs to be refreshed. Click here to re-connect to google.')
    redirect_to google_integration_path(google_integration),
                alert: "<a href='#{new_account_path(provider: :google, redirect: google_integration_path(google_integration))}'>#{alert_notice}</a>"
  end
end
