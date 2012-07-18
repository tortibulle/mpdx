class Api::V1::PeopleController < Api::V1::BaseController

  def index
    render json: current_user.people.includes(:phone_numbers, :email_addresses)
  end

end
