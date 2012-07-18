class Api::V1::ContactsController < Api::V1::BaseController

  def index
    render json: current_user.contacts.includes(:people, :addresses)
  end

end
