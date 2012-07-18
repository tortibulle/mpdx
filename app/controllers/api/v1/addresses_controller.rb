class Api::V1::AddressesController < Api::V1::BaseController

  def index
    render json: current_user.contact_addresses
  end

end
