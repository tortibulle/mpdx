class Api::V1::PreferencesController < Api::V1::BaseController

  def index
    preferences = current_user.preferences.except(:setup)
    preferences[:account_list_id] ||= current_account_list.id
    preferences[:locale] ||= locale
    render json: {preferences: preferences}, callback: params[:callback]
  end

end
