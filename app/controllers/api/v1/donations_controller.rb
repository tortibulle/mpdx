class Api::V1::DonationsController < Api::V1::BaseController
  # NOT SCOPED AT ALL, DO NOT INTEGRATE INTO MASTER BRANCH
  def index
    render json: Contact.find(params[:contact_id]).donations, callback: params[:callback]
  end

  protected

end
