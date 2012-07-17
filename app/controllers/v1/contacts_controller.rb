class V1::ContactsController < V1::BaseController

  def index
    render json: current_user.contacts
  end
end
