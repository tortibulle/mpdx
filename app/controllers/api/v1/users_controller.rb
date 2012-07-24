class Api::V1::UsersController < Api::V1::BaseController

  def show
    user = params[:id] == 'me' ? current_user : User.where(id: current_user.account_lists.includes(:account_list_users).collect(&:account_list_users).flatten.collect(&:user_id)).find(params[:id])
    render json: user, callback: params[:callback]
  end

end
