class Api::V1::PreferencesController < Api::V1::BaseController
  def index
    preferences = current_user.preferences.except(:setup)
    preferences[:account_list_id] ||= current_account_list.id
    preferences[:locale] ||= locale
    render json: { preferences: preferences }, callback: params[:callback]
  end

  def update
    account_list = current_user.account_lists.find(params[:id])
    account_list ||= current_account_list
    @preference_set = PreferenceSet.new(params[:preference_set].merge!(user: current_user, account_list: account_list))
    if @preference_set.save
      render json: { preferences: @preference_set }, callback: params[:callback]
    else
      render json: { errors: @preference_set.errors.full_messages }, callback: params[:callback], status: :bad_request
    end
  end
end
