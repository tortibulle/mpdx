class Api::V1::EmailAddressesController < Api::V1::BaseController

  def index
    render json: current_user.contact_email_addresses, callback: params[:callback]

  end

end
