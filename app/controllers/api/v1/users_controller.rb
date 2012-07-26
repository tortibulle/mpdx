class Api::V1::UsersController < Api::V1::BaseController

  def show
    user = if params[:id] == 'me'
             current_user
           else
             # Allow a user to see user information for anyone else they share an account list with
             User.where(id: current_user.account_lists.includes(:account_list_users).collect(&:account_list_users).flatten.collect(&:user_id)).find(params[:id])
           end
    render json: user, callback: params[:callback]
  end

end
