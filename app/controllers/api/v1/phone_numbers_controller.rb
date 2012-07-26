class Api::V1::PhoneNumbersController < Api::V1::BaseController

  def index
    render json: current_user.contact_phone_numbers, callback: params[:callback]
  end

end
