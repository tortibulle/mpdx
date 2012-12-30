class Api::V1::PreferencesController < Api::V1::BaseController

  def index
    preferences = current_user.preferences.except(:setup)
    if current_account_list
      preferences[:account_list_id] ||= current_account_list.id
      preferences[:locale] ||= locale
      render json: {preferences: preferences}, callback: params[:callback]
    else
      render json: {errors: _('You need to go to http://mpdx.org and set up your account before using the mobile app.')}, callback: params[:callback]
    end
  end

end
