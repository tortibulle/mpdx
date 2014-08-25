class Api::V1::AppealsController < Api::V1::BaseController
  def index
    render json: appeals, callback: params[:callback]
  end

  def update
    #current_user.update_attributes(user_params)
    #render json: user, callback: params[:callback]
  end

  private

  def appeals
    al = AccountList.find(params[:account_list_id])
    al.appeals.includes(:contacts)
  end
end
