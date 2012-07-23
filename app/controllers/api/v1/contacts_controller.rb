class Api::V1::ContactsController < Api::V1::BaseController

  def index
    order = params[:order] || 'name'
    render json: current_user.contacts.order(order)
                             .includes({:people => [:email_addresses, :phone_numbers]}, :addresses), 
           callback: params[:callback]
  end

end
