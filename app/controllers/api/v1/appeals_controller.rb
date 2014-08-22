class Api::V1::AppealsController < Api::V1::BaseController
  def index
    render json: appeal, callback: params[:callback]
  end

  def update
    #current_user.update_attributes(user_params)
    #render json: user, callback: params[:callback]
  end

  private

  def appeal
    al = AccountList.find(params[:account_list_id])
    appeals = al.appeals.includes(:contacts)
    return appeals
  end
end
