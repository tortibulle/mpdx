class Api::V1::UsersController < Api::V1::BaseController
  def show
    render json: user, callback: params[:callback]
  end

  def update
    current_user.update_attributes(user_params)
    render json: user, callback: params[:callback]
  end

  private

  def user
    return @user if @user
    if params[:id] == 'me'
      @user = current_user
    else
      # Allow a user to see user information for anyone else they share an account list with
      @user = User.where(id: current_user.account_lists.includes(:account_list_users).map(&:account_list_users).flatten.map(&:user_id)).find(params[:id])
    end
  end

  def user_params
    params.require(:user).permit!
  end
end
