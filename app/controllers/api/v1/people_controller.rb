class Api::V1::PeopleController < Api::V1::BaseController

  def index
    render json: people, callback: params[:callback]
  end

  def show
    render json: people.find(params[:id]), callback: params[:callback]
  end

  protected

  def people
    current_account_list.people.includes(:phone_numbers, :email_addresses)
  end

end
