class Api::V1::DonationsController < Api::V1::BaseController
  def index
    order = params[:order] || 'donations.id'

    if params[:contact_id].present?
      donor_account_ids = current_account_list.contacts.find(params[:contact_id]).donor_account_ids
      filtered_donations = current_account_list.donations.where(donor_account_id: donor_account_ids)
    end
    filtered_donations ||= donations

    filtered_donations = add_includes_and_order(filtered_donations, per_page: params[:limit], order: order)
    render json: filtered_donations,
           scope: { user: current_user, account_list: current_account_list, locale: locale },
           callback: params[:callback]
  end

  delegate :donations, to: :current_account_list

  protected

  def available_includes
    [:donor_account]
  end
end
