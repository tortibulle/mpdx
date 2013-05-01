class Api::V1::ContactsController < Api::V1::BaseController

  def index
    order = params[:order] || 'name'

    if params[:filters].present?
      filtered_contacts = ContactFilter.new(params[:filters]).filter(contacts)
    else
      filtered_contacts = contacts.active
    end

    render json: add_includes_and_order(filtered_contacts, order: order),
           scope: {since: params[:since]},
           meta:  params[:since] ?
                    {deleted: Version.where(item_type: 'Contact', event: 'destroy', related_object_type: 'AccountList', related_object_id: current_account_list.id).where("created_at > ?", Time.at(params[:since].to_i)).pluck(:item_id)} :
                    {},
           callback: params[:callback]
  end

  def show
    render json: contacts.find(params[:id]),
           scope: {since: params[:since]},
           callback: params[:callback]
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

  def available_includes
    [{:people => [:email_addresses, :phone_numbers, :facebook_account]}, :addresses, {primary_person: :facebook_account}]
  end

end
