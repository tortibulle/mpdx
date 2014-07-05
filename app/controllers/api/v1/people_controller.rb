class Api::V1::PeopleController < Api::V1::BaseController
  def index
    render json: people, callback: params[:callback]
  end

  def show
    render json: people.find(params[:id]), callback: params[:callback]
  end

  protected

  def people
    # We want all the people associated with contacts, and also other users of this account list
    Person.where(id: current_account_list.people.pluck('people.id') + current_account_list.users.pluck('people.id'))
          .includes(:phone_numbers, :email_addresses)
  end
end
