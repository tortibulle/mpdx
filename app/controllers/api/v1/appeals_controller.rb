class Api::V1::AppealsController < Api::V1::BaseController
  def index
    render json: appeals, callback: params[:callback]
  end

  def update
    if appeal.update_attributes(appeal_params) && appeal.add_contacts(current_account_list, params[:appeal][:contacts])
      render json: appeal, callback: params[:callback]
    else
      render json: { errors: task.errors.full_messages }, callback: params[:callback], status: :bad_request
    end
  end

  def destroy
    appeal = appeals.find(params[:id])
    appeal.destroy
    #render json: task, callback: params[:callback]
  end

  def create
    appeal = appeal.new(appeal_params)
    if appeal.save
      render json: appeal, callback: params[:callback], status: :created
    else
      render json: { errors: task.errors.full_messages }, callback: params[:callback], status: :bad_request
    end
  end

  private

  def appeals
    current_account_list.appeals.includes(:contacts)
  end

  def appeal
    current_account_list.appeals.find(params['id'])
  end

  def appeal_params
    @appeal_params ||= params.require(:appeal).permit(Appeal::PERMITTED_ATTRIBUTES)
  end
end
