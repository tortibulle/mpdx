class Api::V1::ContactsController < Api::V1::BaseController

  def index
    order = params[:order] || 'name'
    render json: contacts.order(order)
                                  .includes({:people => [:email_addresses, :phone_numbers]}, :addresses),
           callback: params[:callback]
  end

  def show
    render json: contacts.find(params[:id]), callback: params[:callback]
  end

  def update
    contact = contacts.find(params[:id])
    if contact.update_attributes(params[:contact])
      render json: contact, callback: params[:callback]
    else
      render json: {errors: contact.errors.full_messages}, callback: params[:callback], status: :bad_request
    end
  end

  def create
    contact = contacts.new(params[:contact])
    if contact.save
      render json: contact, callback: params[:callback], status: :created
    else
      render json: {errors: contact.errors.full_messages}, callback: params[:callback], status: :bad_request
    end
  end

  def destroy
    contact = contacts.find(params[:id])
    contact.destroy
    render json: contact, callback: params[:callback]
  end

  protected

  def contacts
    current_account_list.contacts
  end

end
